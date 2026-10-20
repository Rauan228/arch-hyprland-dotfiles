import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "fmt.js" as Fmt
import "names.js" as Names

// Диспетчер задач Serpantinum. Данные — реальные (collector.py читает /proc, /sys, DRM fdinfo, hyprctl, nvidia-smi).
// Ограничение Linux: сетевая активность по процессам без повышенных привилегий недоступна, поэтому сеть
// показана только суммарно (карточка «Сеть» и вкладка «Производительность»).
Scope {
    id: root
    property bool shown: false
    property bool minimized: false
    property var data: null
    property int tick: 0
    property string tab: "procs"          // procs | perf | history | startup | users | details | services | settings
    property string search: ""
    property var hist: ({})
    readonly property int histLen: 60

    // параметры (~/.config/serpantinum/taskmgr.json)
    property int interval: 1000
    property string startTab: "procs"
    property bool groupByType: false

    property string sortKey: "name"
    property bool sortDesc: false
    property var expanded: ({})
    property string selectedKey: ""
    property var selectedRow: null
    property var startupItems: []
    property var serviceItems: []
    property string perfSel: "cpu"
    property var iconCache: ({})

    property bool compact: false           // узкое окно (экран ноутбука)
    readonly property string winSel: "title:^(Диспетчер задач)$"

    function open() {
        if (minimized) { restore(); return; }
        if (!shown) tab = startTab;
        shown = true;
    }
    function toggle() { if (shown && !minimized) shown = false; else open(); }
    // свернуть / вернуть / развернуть — как у всех окон (scripts/bin/serp-win, serp-max): фокус следующему окну,
    // возврат на своё место, анимация; раньше окно переносилось напрямую и фокус оставался на невидимом
    readonly property string bin: Quickshell.env("HOME") + "/.config/serpantinum/bin/"
    function winAddr() {
        var list = Hyprland.toplevels.values;
        for (var i = 0; i < list.length; i++)
            if (list[i] && list[i].title === "Диспетчер задач") return "0x" + String(list[i].address).replace(/^0x/, "");
        return "";
    }
    function restore() {
        minimized = false;
        var a = winAddr(); if (a) Quickshell.execDetached([bin + "serp-win", "restore", a]);
    }
    function minimize() {
        minimized = true;
        var a = winAddr(); if (a) Quickshell.execDetached([bin + "serp-win", "min", a]);
    }
    function toggleMaximize() { var a = winAddr(); if (a) Quickshell.execDetached([bin + "serp-max", "toggle", a]); }

    IpcHandler {
        target: "taskmgr"
        function toggle(): void { root.toggle() }
        function open(): void { root.open() }
        function close(): void { root.shown = false }
        function tab(name: string): void { root.open(); root.tab = name }
    }

    // ---------- параметры ----------
    FileView {
        id: cfg
        path: Quickshell.env("HOME") + "/.config/serpantinum/taskmgr.json"
        printErrors: false
        onLoaded: {
            try {
                var o = JSON.parse(text());
                if (o.interval !== undefined) root.interval = o.interval;
                if (o.startTab) root.startTab = o.startTab;
                if (o.groupByType !== undefined) root.groupByType = o.groupByType;
            } catch (e) {}
        }
    }
    function setOption(k, v) {
        root[k] = v;
        cfg.setText(JSON.stringify({ interval: root.interval, startTab: root.startTab, groupByType: root.groupByType }, null, 2) + "\n");
    }

    // ---------- данные ----------
    Process {
        id: collector
        running: root.shown && root.interval > 0
        command: ["python3", "-I", Quickshell.shellPath("taskmgr/collector.py"), String(Math.max(root.interval, 250) / 1000)]
        stdout: SplitParser {
            onRead: line => {
                try { root.data = JSON.parse(line); } catch (e) { return; }
                root.pushHistory(root.data);
                root.tick++;
            }
        }
    }
    onIntervalChanged: if (collector.running) { collector.running = false; collector.running = Qt.binding(function() { return root.shown && root.interval > 0; }); }
    onShownChanged: if (!shown) { data = null; hist = ({}); selectedKey = ""; selectedRow = null; menu.visible = false; dialog.visible = false; minimized = false }

    function push(key, v) {
        var a = hist[key] || [];
        a.push(v); if (a.length > histLen) a.shift();
        hist[key] = a;
    }
    function netTotal(d) { var s = 0; for (var n in d.net) s += d.net[n].rx + d.net[n].tx; return s; }
    function rootDisk(d) { return d.rootdev && d.disk[d.rootdev] ? d.disk[d.rootdev] : null; }
    function pushHistory(d) {
        push("cpu", d.cpu.total);
        push("mem", d.mem.total ? 100 * d.mem.used / d.mem.total : 0);
        if (d.gpu) { push("gpu", d.gpu.util || 0); push("gpumem", d.gpu.mem_total ? 100 * d.gpu.mem_used / d.gpu.mem_total : 0); }
        if (d.igpu) push("igpu", d.igpu.util || 0);
        for (var k in d.disk) push("disk:" + k, d.disk[k].busy);
        for (var n in d.net) { push("rx:" + n, d.net[n].rx); push("tx:" + n, d.net[n].tx); }
        push("net", netTotal(d) * 8);
    }

    // ---------- вспомогательное ----------
    readonly property var critical: ["Hyprland", "sddm", "sddm-helper", "systemd", "dbus-daemon", "dbus-broker", "quickshell", "NetworkManager", "Xorg", "polkitd", "systemd-logind"]
    function isCritical(name) { return critical.indexOf(name) >= 0; }

    function entryFor(cls) {
        var e = null;
        try { e = DesktopEntries.heuristicLookup(cls); } catch (x) {}
        return e;
    }
    function iconFor(cls) {
        if (iconCache[cls] !== undefined) return iconCache[cls];
        var e = entryFor(cls);
        var p = "";
        if (e && e.icon) p = Quickshell.iconPath(e.icon, true) || "";
        if (!p) p = Quickshell.iconPath(cls, true) || Quickshell.iconPath(String(cls).toLowerCase(), true) || "";
        iconCache[cls] = p;
        return p;
    }

    // comm в Linux обрезается до 15 символов — берём полное имя из командной строки
    function displayName(p) {
        if (p.name.length < 15) return p.name;
        var a0 = String(p.cmd).split(" ")[0];
        var base = a0.substring(a0.lastIndexOf("/") + 1);
        return base.indexOf(p.name) === 0 ? base : p.name;
    }

    // иконка темы: сначала через Quickshell, затем из найденных файлов breeze-dark / breeze / Adwaita
    property var iconIndex: ({})
    function themeIcon(n) {
        var k = "theme:" + n;
        if (iconCache[k]) return iconCache[k];
        var p = Quickshell.iconPath(n, true) || (iconIndex[n] ? "file://" + iconIndex[n] : "");
        if (p) iconCache[k] = p;
        return p;
    }
    Process {
        id: iconScan
        property var found: ({})
        running: true
        command: ["bash", "-c", "args=(); for n in \"$@\"; do args+=(-o -name \"$n.svg\" -o -name \"$n.png\"); done; " +
                  "find /usr/share/icons/breeze-dark /usr/share/icons/breeze /usr/share/icons/Adwaita /usr/share/icons/hicolor \\( -false \"${args[@]}\" \\) 2>/dev/null", "scan"].concat(Names.iconNames())
        stdout: SplitParser { onRead: line => {
            var b = line.substring(line.lastIndexOf("/") + 1).replace(/\.(svg|png)$/, "");
            // приоритет: breeze-dark > breeze > Adwaita > hicolor, крупный/векторный размер
            var score = (line.indexOf("/breeze-dark/") >= 0 ? 40 : line.indexOf("/breeze/") >= 0 ? 30 : line.indexOf("/Adwaita/") >= 0 ? 20 : 10)
                      + (line.indexOf("/scalable/") >= 0 || line.indexOf("/48/") >= 0 || line.indexOf("/48x48/") >= 0 ? 5 : (line.indexOf("/16/") >= 0 || line.indexOf("16x16") >= 0 ? 0 : 3));
            var f = iconScan.found;
            if (!f[b] || f[b].score < score) f[b] = { path: line, score: score };
        } }
        onExited: {
            var idx = {};
            for (var k in found) idx[k] = found[k].path;
            root.iconIndex = idx; root.tick++;
        }
    }

    function cmp(a, b, key, desc) {
        var x = a.sort[key], y = b.sort[key], r;
        if (typeof x === "string") r = x.localeCompare(y, "ru"); else r = (x || 0) - (y || 0);
        return desc ? -r : r;
    }
    function matches(text) { return root.search === "" || String(text).toLowerCase().indexOf(root.search.toLowerCase()) >= 0; }

    function statusOf(procs) {
        var stopped = procs.every(function(p) { return p.state === "T" || p.state === "t"; });
        return stopped ? "Приостановлено" : "";
    }
    function heatOf(cpu, mem, dsk, gpu) {
        return { cpu: cpu / 30, mem: mem / (root.data.mem.total * 0.10), disk: dsk / 20971520, gpu: (gpu || 0) / 25 };
    }

    function procRow(p, depth, name) {
        var dsk = p.disk_r === null ? null : (p.disk_r + (p.disk_w || 0));
        return {
            key: "p:" + p.pid, depth: depth, expandable: false, pids: [p.pid], critical: isCritical(p.name), owner: p.user,
            title: name || p.name, kind: p.kind, leaf: p.nice > 0, nice: p.nice, stopped: p.state === "T",
            icon: depth > 0 ? "" : iconFor(p.name), fallbackIcon: depth > 0 ? "" : "app",
            cells: { name: name || p.name, pid: String(p.pid), state: Fmt.stateName(p.state), user: p.user, status: statusOf([p]),
                     cpu: Fmt.pct0(p.cpu), mem: Fmt.bytes(p.mem), disk: Fmt.rate(dsk), gpu: p.gpu === null ? "—" : Fmt.pct0(p.gpu),
                     threads: String(p.threads), cmd: p.cmd, nice: String(p.nice),
                     cputime: Fmt.duration(p.cputime), runtime: Fmt.duration(root.data.uptime - p.started) },
            sort: { name: (name || p.name).toLowerCase(), pid: p.pid, state: p.state, user: p.user, cpu: p.cpu, mem: p.mem,
                    disk: dsk || 0, gpu: p.gpu || 0, threads: p.threads, cmd: p.cmd, status: p.nice, nice: p.nice,
                    cputime: p.cputime, runtime: root.data.uptime - p.started },
            heat: heatOf(p.cpu, p.mem, dsk || 0, p.gpu)
        };
    }

    function aggRow(key, name, icon, procs, depth, fallback) {
        var cpu = 0, mem = 0, dsk = 0, hasDisk = false, gpu = 0, hasGpu = false, th = 0, pids = [], crit = false, ct = 0, st = 1e12;
        for (var i = 0; i < procs.length; i++) {
            var p = procs[i]; cpu += p.cpu; mem += p.mem; th += p.threads; pids.push(p.pid); ct += p.cputime; st = Math.min(st, p.started);
            if (p.disk_r !== null) { dsk += p.disk_r + (p.disk_w || 0); hasDisk = true; }
            if (p.gpu !== null) { gpu += p.gpu; hasGpu = true; }
            if (isCritical(p.name)) crit = true;
        }
        gpu = Math.min(gpu, 100);
        var multi = procs.length > 1;
        var leaf = procs.every(function(p) { return p.nice > 0; });
        return {
            key: key, depth: depth, expandable: multi, expanded: !!root.expanded[key], pids: pids, critical: crit, owner: procs[0].user,
            icon: icon || "", fallbackIcon: fallback === undefined ? "app" : fallback, title: name, kind: procs[0].kind, children: procs,
            leaf: leaf, stopped: procs.every(function(p) { return p.state === "T"; }),
            cells: { name: name + (multi ? " (" + procs.length + ")" : ""), pid: multi ? "" : String(procs[0].pid), state: multi ? "" : Fmt.stateName(procs[0].state), user: procs[0].user,
                     status: statusOf(procs), cpu: Fmt.pct0(cpu), mem: Fmt.bytes(mem), disk: hasDisk ? Fmt.rate(dsk) : "—", gpu: hasGpu ? Fmt.pct0(gpu) : "—",
                     threads: String(th), cmd: multi ? "" : procs[0].cmd, cputime: Fmt.duration(ct), runtime: Fmt.duration(root.data.uptime - st) },
            sort: { name: name.toLowerCase(), pid: procs[0].pid, state: "", user: procs[0].user, cpu: cpu, mem: mem, disk: dsk, gpu: gpu, threads: th, cmd: "",
                    status: leaf ? 1 : 0, cputime: ct, runtime: root.data.uptime - st },
            heat: heatOf(cpu, mem, dsk, hasGpu ? gpu : 0)
        };
    }

    // группы процессов: окна (приложения) + фоновые/системные по имени
    function groupRows() {
        var d = root.data;
        var groups = { app: {}, background: {}, system: {} };
        var friendlyIcon = {};
        var wins = {}; for (var w = 0; w < d.wins.length; w++) if (!wins[d.wins[w].pid]) wins[d.wins[w].pid] = d.wins[w];
        for (var i = 0; i < d.procs.length; i++) {
            var p = d.procs[i];
            if (p.kind === "kernel") continue;   // потоки ядра — только во вкладке «Подробности»
            if (p.kind === "app") (groups.app[p.group] = groups.app[p.group] || []).push(p);
            else { var fr = Names.friendly(displayName(p)); var nm = fr ? fr.label : displayName(p);
                   if (fr) friendlyIcon[nm] = fr.icon;
                   (groups[p.kind][nm] = groups[p.kind][nm] || []).push(p); }
        }
        var apps = [], bg = [], sys = [];
        for (var g in groups.app) {
            var win = wins[g]; var ps = groups.app[g];
            var ent = win ? entryFor(win.cls) : null;
            var fa = win ? Names.friendly(String(win.cls).replace(/^org\./, "")) : null;
            var name = fa ? fa.label : (ent && ent.name ? ent.name : (win ? win.cls : ps[0].name));
            var r = aggRow("app:" + g, name, fa ? themeIcon(fa.icon) : (win ? iconFor(win.cls) : ""), ps, 0);
            r.isApp = true; apps.push(r);
        }
        for (var n in groups.background) bg.push(aggRow("bg:" + n, n, friendlyIcon[n] ? themeIcon(friendlyIcon[n]) : iconFor(n), groups.background[n], 0));
        for (var m in groups.system) sys.push(aggRow("sys:" + m, m, friendlyIcon[m] ? themeIcon(friendlyIcon[m]) : iconFor(m), groups.system[m], 0, "settings"));
        return { apps: apps, bg: bg, sys: sys };
    }
    function filterRows(rows) {
        return rows.filter(function(r) { return matches(r.title) || (r.children && r.children.some(function(c) { return matches(c.name) || matches(c.pid); })); });
    }
    function expandInto(out, r) {
        out.push(r);
        if (r.expandable && r.expanded) {
            var ch = r.children.slice().sort(function(a, b) { return b.mem - a.mem; });
            ch.forEach(function(c) { out.push(procRow(c, 1)); });
        }
    }

    // ---------- строки таблиц ----------
    readonly property var procRows: {
        root.tick;
        if (!root.data || root.tab !== "procs") return [];
        var sk = root.sortKey, desc = root.sortDesc;
        var g = groupRows(), out = [];
        if (root.groupByType) {
            [["Приложения", g.apps], ["Фоновые процессы", g.bg], ["Системные процессы", g.sys]].forEach(function(s) {
                var rows = filterRows(s[1]);
                if (!rows.length) return;
                rows.sort(function(a, b) { return cmp(a, b, sk, desc); });
                out.push({ key: "sec:" + s[0], section: true, title: s[0] + " (" + rows.length + ")", cells: {} });
                rows.forEach(function(r) { expandInto(out, r); });
            });
        } else {
            var all = filterRows(g.apps.concat(g.bg, g.sys));
            all.sort(function(a, b) {
                if (sk === "name" && !!a.isApp !== !!b.isApp) return a.isApp ? -1 : 1;   // приложения сверху
                return cmp(a, b, sk, desc);
            });
            all.forEach(function(r) { expandInto(out, r); });
        }
        return out;
    }

    readonly property var historyRows: {
        root.tick;
        if (!root.data || root.tab !== "history") return [];
        var g = groupRows();
        var rows = filterRows(g.apps.concat(g.bg)).filter(function(r) { return r.sort.cputime >= 0.1; });
        var sk = root.sortKey, desc = root.sortDesc;
        rows.sort(function(a, b) { return cmp(a, b, sk, desc); });
        var out = []; rows.forEach(function(r) { expandInto(out, r); });
        return out;
    }

    readonly property var detailRows: {
        root.tick;
        if (!root.data || root.tab !== "details") return [];
        var rows = root.data.procs.filter(function(p) { return matches(p.name) || matches(p.cmd) || matches(String(p.pid)); }).map(function(p) { return procRow(p, 0); });
        var sk = root.sortKey, desc = root.sortDesc;
        rows.sort(function(a, b) { return cmp(a, b, sk, desc); });
        return rows;
    }

    readonly property var userRows: {
        root.tick;
        if (!root.data || root.tab !== "users") return [];
        var by = {};
        root.data.procs.forEach(function(p) { (by[p.user] = by[p.user] || []).push(p); });
        var rows = [];
        for (var u in by) {
            var r = aggRow("user:" + u, u, "", by[u], 0, "users");
            r.cells.name = u + " (" + by[u].length + " проц.)"; r.expandable = true; r.expanded = !!root.expanded["user:" + u];
            rows.push(r);
        }
        var sk = root.sortKey, desc = root.sortDesc;
        rows.sort(function(a, b) { return cmp(a, b, sk, desc); });
        var out = [];
        rows.forEach(function(r) {
            out.push(r);
            if (r.expanded) {
                var byName = {}; r.children.forEach(function(p) { (byName[p.name] = byName[p.name] || []).push(p); });
                var sub = []; for (var n in byName) sub.push(aggRow("userproc:" + r.key + ":" + n, n, "", byName[n], 1, ""));
                sub.sort(function(a, b) { return b.sort.mem - a.sort.mem; }).forEach(function(s) { out.push(s); });
            }
        });
        return out;
    }

    readonly property var startupRows: {
        var rows = root.startupItems.filter(function(s) { return matches(s.name) || matches(s.exec); }).map(function(s) {
            return { key: "su:" + s.file, depth: 0, expandable: false, title: s.name, file: s.file, enabled: s.enabled, origin: s.origin,
                     icon: iconFor(s.name), fallbackIcon: "app",
                     cells: { name: s.name, status: s.enabled ? "Включено" : "Отключено", origin: s.origin === "user" ? "Пользователь" : "Система", cmd: s.exec },
                     sort: { name: s.name.toLowerCase(), status: s.enabled ? 1 : 0, origin: s.origin, cmd: s.exec }, heat: {} };
        });
        var sk = root.sortKey, desc = root.sortDesc;
        rows.sort(function(a, b) { return cmp(a, b, sk, desc); });
        return rows;
    }
    readonly property var serviceRows: {
        var rows = root.serviceItems.filter(function(s) { return matches(s.name) || matches(s.desc); }).map(function(s) {
            return { key: "svc:" + s.name, depth: 0, expandable: false, title: s.name, unit: s.name, active: s.active, sub: s.sub, fallbackIcon: "services",
                     cells: { name: s.name.replace(/\.service$/, ""), status: s.active === "active" ? (s.sub === "running" ? "Выполняется" : "Активна") : (s.active === "failed" ? "Ошибка" : "Остановлена"), desc: s.desc },
                     sort: { name: s.name.toLowerCase(), status: s.active, desc: s.desc }, heat: {} };
        });
        var sk = root.sortKey, desc = root.sortDesc;
        rows.sort(function(a, b) { return cmp(a, b, sk, desc); });
        return rows;
    }

    // ---------- действия ----------
    function endTask(row, force) {
        if (!row || !row.pids) return;
        Quickshell.execDetached(["kill", force ? "-KILL" : "-TERM"].concat(row.pids.map(String)));
    }
    function requestEnd(row, force) {
        if (!row || !row.pids) return;
        if (row.critical) {
            dialog.title = "Завершить системный процесс?";
            dialog.text = "«" + row.title + "» — критический процесс. Его завершение может закрыть сессию или нарушить работу системы.";
            dialog.confirmText = force ? "Принудительно завершить" : "Завершить";
        } else if (force) {
            dialog.title = "Принудительно завершить «" + row.title + "»?";
            dialog.text = "Процесс будет остановлен сигналом KILL без сохранения данных.";
            dialog.confirmText = "Принудительно завершить";
        } else { endTask(row, false); return; }
        dialog.action = function() { root.endTask(row, force); };
        dialog.input = false;
        dialog.visible = true;
    }
    // режим эффективности = пониженный приоритет (nice 10); вернуть обычный приоритет может только root
    function setEfficiency(row, on) {
        if (!row || !row.pids) return;
        if (on) Quickshell.execDetached(["renice", "-n", "10", "-p"].concat(row.pids.map(String)));
        else Quickshell.execDetached(["pkexec", "renice", "-n", "0", "-p"].concat(row.pids.map(String)));
    }
    function setSuspended(row, on) {
        if (!row || !row.pids) return;
        Quickshell.execDetached(["kill", on ? "-STOP" : "-CONT"].concat(row.pids.map(String)));
    }
    function openLocation(row) {
        if (!row || !row.pids || !row.pids.length) return;
        Quickshell.execDetached(["sh", "-c", "d=$(dirname \"$(readlink -f /proc/" + row.pids[0] + "/exe)\") && exec thunar \"$d\""]);
    }
    function newTask() {
        dialog.title = "Создание новой задачи"; dialog.text = "Введите команду или имя программы:";
        dialog.confirmText = "Запустить"; dialog.input = true; dialog.inputText = "";
        dialog.action = function(v) { if (v) Quickshell.execDetached(["sh", "-c", v]); };
        dialog.visible = true;
    }
    function reloadStartup() { startupProc.running = false; startupProc.buf = []; startupProc.running = true; }
    function reloadServices() { svcProc.running = false; svcProc.buf = []; svcProc.running = true; }
    onTabChanged: {
        search = ""; searchInput.text = ""; menu.visible = false; selectedKey = ""; selectedRow = null;
        sortKey = tab === "users" ? "mem" : (tab === "history" ? "cputime" : "name");
        sortDesc = tab === "users" || tab === "history";
        if (tab === "startup") reloadStartup();
        if (tab === "services") reloadServices();
    }
    function sortBy(key) {
        if (sortKey === key) sortDesc = !sortDesc; else { sortKey = key; sortDesc = ["name", "user", "cmd", "state", "origin", "desc"].indexOf(key) < 0; }
    }
    function toggleExpand(row) { var e = expanded; e[row.key] = !e[row.key]; expanded = e; root.tick++; }
    function setAllExpanded(on) {
        var e = {};
        if (on) procRows.forEach(function(r) { if (r.expandable) e[r.key] = true; });
        expanded = e; root.tick++;
    }

    Process {
        id: startupProc
        property var buf: []
        command: ["bash", Quickshell.shellPath("taskmgr/startup.sh")]
        stdout: SplitParser { onRead: line => { var p = line.split("\t"); if (p.length >= 5) startupProc.buf.push({ name: p[0], exec: p[1], enabled: p[2] === "1", file: p[3], origin: p[4] }); } }
        onExited: root.startupItems = buf.slice()
    }
    Process {
        id: svcProc
        property var buf: []
        command: ["systemctl", "list-units", "--type=service", "--all", "--no-pager", "--plain", "--no-legend"]
        stdout: SplitParser { onRead: line => {
            var m = line.trim().match(/^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s*(.*)$/);
            if (m && m[2] !== "not-found") svcProc.buf.push({ name: m[1], active: m[3], sub: m[4], desc: m[5] });
        } }
        onExited: root.serviceItems = buf.slice()
    }

    readonly property var pages: [
        { id: "procs", icon: "procs", label: "Процессы" },
        { id: "perf", icon: "perf", label: "Производительность" },
        { id: "history", icon: "history", label: "Журнал приложений" },
        { id: "startup", icon: "startup", label: "Автозагрузка" },
        { id: "users", icon: "users", label: "Пользователи" },
        { id: "details", icon: "details", label: "Подробности" },
        { id: "services", icon: "services", label: "Службы" }
    ]
    readonly property var pageTitle: ({ procs: "Процессы", perf: "Производительность", history: "Журнал приложений", startup: "Автозагрузка",
                                        users: "Пользователи", details: "Подробности", services: "Службы", settings: "Параметры" })

    // ---------- окно ----------
    FloatingWindow {
        id: win
        visible: root.shown
        title: "Диспетчер задач"
        implicitWidth: 1240
        implicitHeight: 760
        color: "transparent"
        onVisibleChanged: if (!visible) root.shown = false

        component NavItem: Rectangle {
            id: nav
            property string page: ""
            property string icon: ""
            property string label: ""
            readonly property bool on: root.tab === page
            Layout.fillWidth: true; Layout.preferredHeight: root.compact ? 40 : 44
            radius: 8
            color: on ? Style.a(Style.accent, 0.13) : (nma.containsMouse ? Style.hover : "transparent")
            border.width: on ? 1 : 0; border.color: Style.a(Style.accent, 0.30)
            Behavior on color { ColorAnimation { duration: 130 } }
            Row {
                anchors { left: parent.left; leftMargin: root.compact ? 12 : 16; verticalCenter: parent.verticalCenter } spacing: root.compact ? 11 : 14
                Icon { name: nav.icon; width: 20; height: 20; color: nav.on ? Style.text : Style.sub; anchors.verticalCenter: parent.verticalCenter }
                Text { text: nav.label; color: Style.text; font { family: Style.font; pixelSize: 14; weight: nav.on ? Font.Medium : Font.Normal } anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea { id: nma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.tab = nav.page }
        }

        component ToolButton: Rectangle {
            id: tb
            property string icon: ""
            property string label: ""
            property bool enabledState: true
            signal clicked(real gx, real gy)
            implicitWidth: (label === "" ? 36 : tbl.implicitWidth + 50); implicitHeight: 34
            radius: 7
            opacity: enabledState ? 1 : 0.45
            color: tma.containsMouse && enabledState ? Qt.rgba(1, 1, 1, 0.09) : Style.field
            border.width: 1; border.color: Style.line
            Icon { id: tbi; name: tb.icon; width: 18; height: 18; color: Style.text; anchors { left: parent.left; leftMargin: tb.label === "" ? 9 : 12; verticalCenter: parent.verticalCenter } }
            Text { id: tbl; visible: tb.label !== ""; text: tb.label; color: Style.text; font { family: Style.font; pixelSize: 12 } anchors { left: tbi.right; leftMargin: 9; verticalCenter: parent.verticalCenter } }
            MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; enabled: tb.enabledState; cursorShape: Qt.PointingHandCursor
                        onClicked: { var p = mapToItem(null, 0, height + 4); tb.clicked(p.x, p.y) } }
        }

        component WinButton: Rectangle {
            id: wb
            property string icon: ""
            property bool danger: false
            signal clicked()
            width: 46; height: 34; radius: 7
            color: wbm.containsMouse ? (danger ? Style.danger : Style.hover) : "transparent"
            Icon { anchors.centerIn: parent; width: 17; height: 17; name: wb.icon; color: wbm.containsMouse && wb.danger ? "white" : Style.sub; stroke: 1.4 }
            MouseArea { id: wbm; anchors.fill: parent; hoverEnabled: true; onClicked: wb.clicked() }
        }

        Rectangle {
            id: frame
            anchors.fill: parent
            color: Style.glass
            border.width: 1; border.color: Style.border
            onWidthChanged: root.compact = width < 1300
            focus: true
            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Escape) { if (dialog.visible) dialog.visible = false; else if (menu.visible) menu.visible = false; else root.shown = false; e.accepted = true; }
                else if (e.key === Qt.Key_Delete && root.selectedRow && root.selectedRow.pids) { root.requestEnd(root.selectedRow, (e.modifiers & Qt.ShiftModifier) !== 0); e.accepted = true; }
                else if (e.key === Qt.Key_F && (e.modifiers & Qt.ControlModifier)) { searchInput.forceActiveFocus(); e.accepted = true; }
            }

            // --- заголовок: логотип, название, поиск, кнопки окна ---
            Item {
                id: titleBar
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 64
                MouseArea {
                    anchors.fill: parent
                    onPressed: { try { titleBar.Window.window.startSystemMove(); } catch (e) {} }
                    onDoubleClicked: root.toggleMaximize()
                }
                Row {
                    anchors { left: parent.left; leftMargin: 22; verticalCenter: parent.verticalCenter } spacing: 14
                    Rectangle {
                        width: 34; height: 34; radius: 8; anchors.verticalCenter: parent.verticalCenter
                        color: Style.a(Style.accent, 0.14); border.width: 1; border.color: Style.a(Style.accent, 0.35)
                        Icon { anchors.centerIn: parent; width: 22; height: 22; name: "logo"; color: Style.accent; stroke: 1.5 }
                    }
                    Text { text: "Диспетчер задач"; color: Style.text; font { family: Style.font; pixelSize: 17; weight: Font.Medium } anchors.verticalCenter: parent.verticalCenter }
                }
                Rectangle {
                    id: searchBox
                    anchors.centerIn: parent
                    width: Math.min(530, parent.width - 620); height: 36; radius: 8
                    visible: root.tab !== "perf" && root.tab !== "settings"
                    color: Style.field; border.width: 1; border.color: searchInput.activeFocus ? Style.a(Style.accent, 0.6) : Style.line
                    Icon { name: "search"; width: 17; height: 17; color: Style.sub; anchors { left: parent.left; leftMargin: 13; verticalCenter: parent.verticalCenter } }
                    TextInput {
                        id: searchInput
                        anchors { fill: parent; leftMargin: 42; rightMargin: 12 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Style.text; font { family: Style.font; pixelSize: 13 }
                        selectionColor: Style.a(Style.accent, 0.4)
                        clip: true
                        onTextChanged: root.search = text
                        Text { visible: parent.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Поиск процессов, имён, PID…"; color: Style.dim; font: parent.font }
                    }
                }
                // кнопки окна — в общем заголовке (hyprbars, стиль macOS)
            }

            RowLayout {
                anchors { left: parent.left; right: parent.right; top: titleBar.bottom; bottom: parent.bottom; leftMargin: 12; rightMargin: 14; bottomMargin: 14 }
                spacing: 12

                // --- левая навигация ---
                ColumnLayout {
                    Layout.preferredWidth: root.compact ? 186 : 212; Layout.maximumWidth: root.compact ? 186 : 212; Layout.fillWidth: false; Layout.fillHeight: true
                    spacing: 6
                    Repeater {
                        model: root.pages
                        delegate: NavItem { required property var modelData; page: modelData.id; icon: modelData.icon; label: modelData.label }
                    }
                    Item { Layout.fillHeight: true }
                    NavItem { page: "settings"; icon: "settings"; label: "Параметры" }
                }

                // --- основная панель ---
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    radius: 10; color: Style.panel; border.width: 1; border.color: Style.line
                    clip: true

                    ColumnLayout {
                        anchors { fill: parent; margins: 10 }
                        spacing: 10

                        // панель действий
                        RowLayout {
                            Layout.fillWidth: true; Layout.preferredHeight: 36
                            spacing: 8
                            Text {
                                Layout.leftMargin: 6
                                visible: root.tab !== "procs"
                                text: root.pageTitle[root.tab] || ""
                                color: Style.text; font { family: Style.font; pixelSize: 15; weight: Font.Medium }
                            }
                            Item { Layout.fillWidth: true }
                            ToolButton { icon: "newtask"; label: "Запустить новую задачу"; onClicked: root.newTask() }
                            ToolButton {
                                visible: ["procs", "history", "details", "users"].indexOf(root.tab) >= 0
                                icon: "endtask"; label: "Завершить задачу"
                                enabledState: root.selectedRow !== null && root.selectedRow.pids !== undefined
                                onClicked: root.requestEnd(root.selectedRow, false)
                            }
                            ToolButton {
                                icon: "more"
                                onClicked: (gx, gy) => menu.openGeneral(gx - 200, gy)
                            }
                        }

                        // карточки ресурсов (только «Процессы»)
                        RowLayout {
                            id: cards
                            visible: root.tab === "procs" && root.data !== null
                            Layout.fillWidth: true; Layout.fillHeight: false; Layout.preferredHeight: root.compact ? 90 : 100; Layout.maximumHeight: root.compact ? 90 : 100
                            spacing: 10
                            readonly property var d: root.data
                            readonly property var rd: d ? root.rootDisk(d) : null
                            StatCard {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                label: "ЦП"; accent: Style.cpu; tick: root.tick; values: { root.tick; return root.hist.cpu || []; } autoMax: true
                                value: cards.d ? Fmt.pct(cards.d.cpu.total, 0) : "—"
                                sub: cards.d && cards.d.cpu.freq ? (cards.d.cpu.freq / 1000).toFixed(2).replace(".", ",") + " ГГц" : ""
                                onClicked: { root.perfSel = "cpu"; root.tab = "perf" }
                            }
                            StatCard {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                label: "Память"; accent: Style.mem; tick: root.tick; values: { root.tick; return root.hist.mem || []; }
                                value: cards.d ? Fmt.pct(100 * cards.d.mem.used / cards.d.mem.total, 0) : "—"
                                sub: cards.d ? (cards.d.mem.used / 1073741824).toFixed(1).replace(".", ",") + " / " + (cards.d.mem.total / 1073741824).toFixed(1).replace(".", ",") + " ГБ" : ""
                                onClicked: { root.perfSel = "mem"; root.tab = "perf" }
                            }
                            StatCard {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                label: "Диск (/)"; accent: Style.disk; tick: root.tick; autoMax: true
                                values: { root.tick; return cards.d && cards.d.rootdev ? (root.hist["disk:" + cards.d.rootdev] || []) : []; }
                                value: cards.rd ? Fmt.pct(cards.rd.busy, 0) : "—"
                                sub: cards.rd ? Fmt.rate(cards.rd.read + cards.rd.write) : ""
                                onClicked: { if (cards.d && cards.d.rootdev) root.perfSel = "disk:" + cards.d.rootdev; root.tab = "perf" }
                            }
                            StatCard {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                label: "Сеть"; accent: Style.net; tick: root.tick; values: { root.tick; return root.hist.net || []; } autoMax: true
                                value: cards.d ? Fmt.bits(root.netTotal(cards.d)) : "—"
                                sub: cards.d ? Object.keys(cards.d.net).filter(function(n) { return cards.d.net[n].up; }).map(function(n) { return (n.indexOf("wl") === 0 ? "Wi-Fi" : (n.indexOf("en") === 0 || n.indexOf("eth") === 0 ? "Ethernet" : n)); }).join(", ") : ""
                                onClicked: { var k = cards.d ? Object.keys(cards.d.net) : []; if (k.length) root.perfSel = "net:" + k[0]; root.tab = "perf" }
                            }
                            StatCard {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                label: "ГП"; accent: Style.gpu; tick: root.tick; autoMax: true
                                values: { root.tick; return cards.d && cards.d.igpu ? (root.hist.igpu || []) : (root.hist.gpu || []); }
                                value: cards.d ? (cards.d.igpu ? Fmt.pct(cards.d.igpu.util, 0) : (cards.d.gpu ? Fmt.pct(cards.d.gpu.util, 0) : "—")) : "—"
                                sub: cards.d ? ((cards.d.igpu ? cards.d.igpu.name.replace(" Graphics", "") : "") + (cards.d.gpu ? (cards.d.igpu ? "\n" : "") + cards.d.gpu.name.replace("NVIDIA GeForce ", "").replace(" Laptop GPU", "") + ": " + Fmt.pct(cards.d.gpu.util, 0) : "")) : ""
                                onClicked: { root.perfSel = cards.d && cards.d.igpu ? "igpu" : "gpu"; root.tab = "perf" }
                            }
                        }

                        // содержимое вкладок
                        Rectangle {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            radius: 8; color: root.tab === "perf" || root.tab === "settings" ? "transparent" : Qt.rgba(0, 0, 0, 0.24)
                            border.width: root.tab === "perf" || root.tab === "settings" ? 0 : 1; border.color: Style.line
                            clip: true

                            Text {
                                anchors.centerIn: parent
                                visible: root.data === null && ["procs", "history", "users", "details", "perf"].indexOf(root.tab) >= 0
                                text: root.interval === 0 ? "Обновление на паузе — включите его в «Параметрах»" : "Сбор данных…"
                                color: Style.dim; font { family: Style.font; pixelSize: 13 }
                            }

                            Item {
                                anchors { fill: parent; margins: root.tab === "perf" || root.tab === "settings" ? 0 : 1 }
                                visible: root.data !== null || root.tab === "startup" || root.tab === "services" || root.tab === "settings"

                                DataTable {
                                    anchors.fill: parent; visible: root.tab === "procs"
                                    columns: [
                                        { key: "name", title: "Имя", width: 0 },
                                        { key: "status", title: "Состояние", width: root.compact ? 96 : 136 },
                                        { key: "cpu", title: "ЦП", width: root.compact ? 76 : 96, align: "right" },
                                        { key: "mem", title: "Память", width: root.compact ? 96 : 108, align: "right" },
                                        { key: "disk", title: "Диск", width: root.compact ? 92 : 108, align: "right" },
                                        { key: "gpu", title: "ГП", width: root.compact ? 70 : 86, align: "right" }
                                    ]
                                    headerExtra: root.data ? { cpu: Fmt.pct(root.data.cpu.total, 0), mem: Fmt.pct(100 * root.data.mem.used / root.data.mem.total, 0),
                                                                disk: root.rootDisk(root.data) ? Fmt.pct(root.rootDisk(root.data).busy, 0) : "—",
                                                                gpu: root.data.igpu ? Fmt.pct(root.data.igpu.util, 0) : "—" } : ({})
                                    rows: root.procRows; sortKey: root.sortKey; sortDesc: root.sortDesc; selectedKey: root.selectedKey
                                    onHeaderClicked: key => root.sortBy(key)
                                    onRowClicked: row => { root.selectedKey = row.key; root.selectedRow = row; menu.visible = false }
                                    onToggleRequested: row => root.toggleExpand(row)
                                    onRowRightClicked: (row, gx, gy) => { root.selectedKey = row.key; root.selectedRow = row; menu.openFor(row, gx, gy) }
                                }

                                DataTable {
                                    anchors.fill: parent; visible: root.tab === "history"
                                    columns: [
                                        { key: "name", title: "Имя", width: 0 },
                                        { key: "cputime", title: "Время ЦП", width: 130, align: "right" },
                                        { key: "runtime", title: "Работает", width: 130, align: "right" },
                                        { key: "mem", title: "Память", width: 110, align: "right" },
                                        { key: "gpu", title: "ГП", width: 86, align: "right" }
                                    ]
                                    rows: root.historyRows; sortKey: root.sortKey; sortDesc: root.sortDesc; selectedKey: root.selectedKey
                                    onHeaderClicked: key => root.sortBy(key)
                                    onRowClicked: row => { root.selectedKey = row.key; root.selectedRow = row; menu.visible = false }
                                    onToggleRequested: row => root.toggleExpand(row)
                                    onRowRightClicked: (row, gx, gy) => { root.selectedKey = row.key; root.selectedRow = row; menu.openFor(row, gx, gy) }
                                }

                                DataTable {
                                    anchors.fill: parent; visible: root.tab === "details"
                                    columns: [
                                        { key: "name", title: "Имя", width: 210 },
                                        { key: "pid", title: "PID", width: 76, align: "right" },
                                        { key: "state", title: "Состояние", width: 116 },
                                        { key: "user", title: "Пользователь", width: 116 },
                                        { key: "cpu", title: "ЦП", width: 70, align: "right" },
                                        { key: "mem", title: "Память", width: 92, align: "right" },
                                        { key: "nice", title: "Приоритет", width: 90, align: "right" },
                                        { key: "cmd", title: "Командная строка", width: 0 }
                                    ]
                                    rows: root.detailRows; sortKey: root.sortKey; sortDesc: root.sortDesc; selectedKey: root.selectedKey; rowHeight: 30
                                    onHeaderClicked: key => root.sortBy(key)
                                    onRowClicked: row => { root.selectedKey = row.key; root.selectedRow = row; menu.visible = false }
                                    onRowRightClicked: (row, gx, gy) => { root.selectedKey = row.key; root.selectedRow = row; menu.openFor(row, gx, gy) }
                                }

                                DataTable {
                                    anchors.fill: parent; visible: root.tab === "users"
                                    columns: [
                                        { key: "name", title: "Пользователь", width: 0 },
                                        { key: "cpu", title: "ЦП", width: 96, align: "right" },
                                        { key: "mem", title: "Память", width: 110, align: "right" },
                                        { key: "disk", title: "Диск", width: 110, align: "right" },
                                        { key: "threads", title: "Потоки", width: 90, align: "right" }
                                    ]
                                    rows: root.userRows; sortKey: root.sortKey; sortDesc: root.sortDesc; selectedKey: root.selectedKey
                                    onHeaderClicked: key => root.sortBy(key)
                                    onRowClicked: row => { root.selectedKey = row.key; root.selectedRow = row }
                                    onToggleRequested: row => root.toggleExpand(row)
                                }

                                DataTable {
                                    anchors.fill: parent; visible: root.tab === "startup"
                                    columns: [
                                        { key: "name", title: "Имя", width: 270 },
                                        { key: "status", title: "Состояние", width: 130 },
                                        { key: "origin", title: "Источник", width: 130 },
                                        { key: "cmd", title: "Команда", width: 0 }
                                    ]
                                    rows: root.startupRows; sortKey: root.sortKey; sortDesc: root.sortDesc; selectedKey: root.selectedKey
                                    onHeaderClicked: key => root.sortBy(key)
                                    onRowClicked: row => { root.selectedKey = row.key; root.selectedRow = row; menu.visible = false }
                                    onRowRightClicked: (row, gx, gy) => { root.selectedKey = row.key; root.selectedRow = row; menu.openFor(row, gx, gy) }
                                }

                                DataTable {
                                    anchors.fill: parent; visible: root.tab === "services"
                                    columns: [
                                        { key: "name", title: "Имя", width: 270 },
                                        { key: "status", title: "Состояние", width: 140 },
                                        { key: "desc", title: "Описание", width: 0 }
                                    ]
                                    rows: root.serviceRows; sortKey: root.sortKey; sortDesc: root.sortDesc; selectedKey: root.selectedKey; rowHeight: 30
                                    onHeaderClicked: key => root.sortBy(key)
                                    onRowClicked: row => { root.selectedKey = row.key; root.selectedRow = row; menu.visible = false }
                                    onRowRightClicked: (row, gx, gy) => { root.selectedKey = row.key; root.selectedRow = row; menu.openFor(row, gx, gy) }
                                }

                                PerfView { anchors.fill: parent; visible: root.tab === "perf"; tm: root }
                                SettingsView { anchors.fill: parent; visible: root.tab === "settings"; tm: root }
                            }
                        }
                    }
                }
            }

            // --- контекстное меню ---
            MouseArea { anchors.fill: parent; visible: menu.visible; z: 49; acceptedButtons: Qt.AllButtons; onPressed: menu.visible = false }
            Rectangle {
                id: menu
                visible: false; z: 50
                width: 256; height: mcol.implicitHeight + 12
                radius: 10; color: Style.menuBg
                border.width: 1; border.color: Style.border
                property var items: []
                function show(it, gx, gy) {
                    if (!it.length) return;
                    menu.items = it;
                    menu.x = Math.max(8, Math.min(gx, frame.width - menu.width - 8));
                    menu.y = Math.max(8, Math.min(gy, frame.height - (it.length * 34 + 12) - 8));
                    menu.visible = true;
                }
                function rowItems(row) {
                    var it = [];
                    if (root.tab === "procs" || root.tab === "details" || root.tab === "history") {
                        if (row.expandable) it.push({ label: row.expanded ? "Свернуть" : "Развернуть", act: function() { root.toggleExpand(row) } });
                        it.push({ label: "Снять задачу", act: function() { root.requestEnd(row, false) } });
                        it.push({ label: "Принудительно завершить (KILL)", act: function() { root.requestEnd(row, true) } });
                        if (!row.critical) {
                            it.push({ label: row.leaf ? "Выключить режим эффективности" : "Режим эффективности", act: function() { root.setEfficiency(row, !row.leaf) } });
                            it.push({ label: row.stopped ? "Возобновить" : "Приостановить", act: function() { root.setSuspended(row, !row.stopped) } });
                        }
                        it.push({ label: "Открыть расположение файла", act: function() { root.openLocation(row) } });
                        it.push({ label: "Копировать PID", act: function() { Quickshell.execDetached(["sh", "-c", "printf %s " + row.pids[0] + " | wl-copy"]) } });
                    } else if (root.tab === "startup") {
                        it.push({ label: row.enabled ? "Отключить" : "Включить", act: function() {
                            Quickshell.execDetached(["bash", Quickshell.shellPath("taskmgr/startup-toggle.sh"), row.file, row.enabled ? "0" : "1"]);
                            reloadTimer.start(); } });
                    } else if (root.tab === "services") {
                        [["Запустить", "start"], ["Остановить", "stop"], ["Перезапустить", "restart"]].forEach(function(c) { it.push({ label: c[0] + " (pkexec)", act: function() {
                            dialog.title = c[0] + " службу?"; dialog.text = row.unit + "\nПотребуется подтверждение паролем (pkexec).";
                            dialog.confirmText = c[0]; dialog.input = false;
                            dialog.action = function() { Quickshell.execDetached(["pkexec", "systemctl", c[1], row.unit]); reloadTimer.start(); };
                            dialog.visible = true; } }); });
                    }
                    return it;
                }
                function openFor(row, gx, gy) { show(rowItems(row), gx, gy); }
                function openGeneral(gx, gy) {
                    var it = root.selectedRow ? rowItems(root.selectedRow) : [];
                    if (root.tab === "procs") {
                        it.push({ label: "Развернуть все группы", act: function() { root.setAllExpanded(true) } });
                        it.push({ label: "Свернуть все группы", act: function() { root.setAllExpanded(false) } });
                        it.push({ label: root.groupByType ? "Показать единым списком" : "Группировать по типу", act: function() { root.setOption("groupByType", !root.groupByType) } });
                    }
                    if (root.tab === "startup") it.push({ label: "Обновить список", act: function() { root.reloadStartup() } });
                    if (root.tab === "services") it.push({ label: "Обновить список", act: function() { root.reloadServices() } });
                    it.push({ label: root.interval === 0 ? "Возобновить обновление" : "Приостановить обновление", act: function() { root.setOption("interval", root.interval === 0 ? 1000 : 0) } });
                    it.push({ label: "Параметры", act: function() { root.tab = "settings" } });
                    show(it, gx, gy);
                }
                Column {
                    id: mcol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                    Repeater {
                        model: menu.items
                        delegate: Rectangle {
                            required property var modelData
                            width: mcol.width; height: 34; radius: 7
                            color: mma.containsMouse ? Style.a(Style.accent, 0.16) : "transparent"
                            Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } text: modelData.label; color: Style.text; font { family: Style.font; pixelSize: 13 } }
                            MouseArea { id: mma; anchors.fill: parent; hoverEnabled: true; onClicked: { menu.visible = false; modelData.act(); } }
                        }
                    }
                }
            }

            // --- диалог ---
            Rectangle {
                id: dialog
                visible: false; z: 100; anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.5)
                property string title: ""; property string text: ""; property string confirmText: "OK"
                property bool input: false; property string inputText: ""
                property var action: null
                MouseArea { anchors.fill: parent; onClicked: dialog.visible = false }
                Rectangle {
                    anchors.centerIn: parent; width: 460; height: dcol.implicitHeight + 44
                    radius: 12; color: Style.menuBg; border.width: 1; border.color: Style.border
                    MouseArea { anchors.fill: parent }
                    Column {
                        id: dcol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 22 }
                        spacing: 14
                        Text { width: parent.width; text: dialog.title; wrapMode: Text.Wrap; color: Style.text; font { family: Style.font; pixelSize: 16; weight: Font.Medium } }
                        Text { width: parent.width; text: dialog.text; wrapMode: Text.Wrap; color: Style.sub; font { family: Style.font; pixelSize: 13 } }
                        Rectangle {
                            visible: dialog.input; width: parent.width; height: 38; radius: 8; color: Style.field; border.width: 1; border.color: Style.a(Style.accent, 0.6)
                            TextInput {
                                id: dlgInput
                                anchors { fill: parent; leftMargin: 12; rightMargin: 12 } verticalAlignment: TextInput.AlignVCenter
                                color: Style.text; font { family: Style.font; pixelSize: 13 }
                                text: dialog.inputText; onTextChanged: dialog.inputText = text
                                onAccepted: { dialog.visible = false; if (dialog.action) dialog.action(dialog.inputText); }
                            }
                        }
                        Row {
                            spacing: 10; layoutDirection: Qt.RightToLeft; width: parent.width
                            Rectangle {
                                width: cl.implicitWidth + 32; height: 36; radius: 8; color: cma.containsMouse ? Qt.lighter(Style.accent, 1.1) : Style.accent
                                Text { id: cl; anchors.centerIn: parent; text: dialog.confirmText; color: "#06181b"; font { family: Style.font; pixelSize: 13; weight: Font.DemiBold } }
                                MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; onClicked: { dialog.visible = false; if (dialog.action) dialog.action(dialog.inputText); } }
                            }
                            Rectangle {
                                width: cn.implicitWidth + 32; height: 36; radius: 8; color: cnm.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Style.field
                                border.width: 1; border.color: Style.line
                                Text { id: cn; anchors.centerIn: parent; text: "Отмена"; color: Style.text; font { family: Style.font; pixelSize: 13 } }
                                MouseArea { id: cnm; anchors.fill: parent; hoverEnabled: true; onClicked: dialog.visible = false }
                            }
                        }
                    }
                }
                onVisibleChanged: if (visible && input) dlgInput.forceActiveFocus()
            }
        }
    }

    Timer { id: reloadTimer; interval: 900; onTriggered: { if (root.tab === "startup") root.reloadStartup(); if (root.tab === "services") root.reloadServices(); } }
}
