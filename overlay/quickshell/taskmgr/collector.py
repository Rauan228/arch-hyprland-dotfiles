#!/usr/bin/env python3
"""Serpantinum task manager data collector.

Prints one JSON object per line every INTERVAL seconds with real data read from
/proc, /sys, hyprctl and nvidia-smi. No fake values: anything unavailable is null.
"""
import json, os, sys, time, subprocess, pwd, shutil

INTERVAL = float(sys.argv[1]) if len(sys.argv) > 1 else 1.0
CLK = os.sysconf("SC_CLK_TCK")
PAGE = os.sysconf("SC_PAGE_SIZE")
NCPU = os.cpu_count() or 1
MY_UID = os.getuid()

def _root_disk():
    """Whole-disk name backing / (e.g. nvme0n1); works for btrfs subvolumes too."""
    src = None
    for line in read("/proc/self/mountinfo").splitlines():
        pre, _, post = line.partition(" - ")
        f = pre.split()
        if len(f) > 4 and f[4] == "/":
            src = post.split()[1] if len(post.split()) > 1 else None
    if not src or not src.startswith("/dev/"):
        return None
    p = os.path.realpath(f"/sys/class/block/{os.path.basename(os.path.realpath(src))}")
    while p and p != "/":
        n = os.path.basename(p)
        if os.path.exists(f"/sys/block/{n}"):
            return n
        p = os.path.dirname(p)
    return None


def read(path, default=""):
    try:
        with open(path, "rb") as f:
            return f.read().decode("utf-8", "replace")
    except OSError:
        return default

_users = {}
def user_of(uid):
    if uid not in _users:
        try:
            _users[uid] = pwd.getpwuid(uid).pw_name
        except KeyError:
            _users[uid] = str(uid)
    return _users[uid]

def cpu_times():
    out = []
    for line in read("/proc/stat").splitlines():
        if line.startswith("cpu"):
            p = line.split()
            v = list(map(int, p[1:9]))
            out.append((p[0], sum(v), v[3] + v[4]))  # name, total, idle+iowait
    return out

def meminfo():
    d = {}
    for line in read("/proc/meminfo").splitlines():
        k, _, v = line.partition(":")
        d[k] = int(v.split()[0]) * 1024 if v.split() else 0
    return d

def net_bytes():
    res = {}
    for line in read("/proc/net/dev").splitlines()[2:]:
        name, _, rest = line.partition(":")
        name = name.strip()
        if name == "lo" or not rest:
            continue
        f = rest.split()
        res[name] = (int(f[0]), int(f[8]))
    return res

def disk_bytes():
    res = {}
    for line in read("/proc/diskstats").splitlines():
        f = line.split()
        if len(f) < 10:
            continue
        name = f[2]
        # whole disks only (nvme0n1, sda), skip partitions/loop/ram/dm
        if name.startswith(("loop", "ram", "dm-", "zram", "sr")):
            continue
        if os.path.exists(f"/sys/block/{name}"):
            res[name] = (int(f[5]) * 512, int(f[9]) * 512, int(f[12]))  # read B, write B, io ms
    return res

def cpu_freq():
    vals = []
    for i in range(NCPU):
        v = read(f"/sys/devices/system/cpu/cpu{i}/cpufreq/scaling_cur_freq").strip()
        if v.isdigit():
            vals.append(int(v) / 1000)
    return sum(vals) / len(vals) if vals else None

def cpu_name():
    for line in read("/proc/cpuinfo").splitlines():
        if line.startswith("model name"):
            return line.split(":", 1)[1].strip()
    return "CPU"

def read_proc(pid):
    base = f"/proc/{pid}"
    try:
        stat = read(base + "/stat")
        if not stat:
            return None
        rp = stat.rfind(")")
        name = stat[stat.find("(") + 1:rp]
        f = stat[rp + 2:].split()
        state, ppid = f[0], int(f[1])
        ticks = int(f[11]) + int(f[12])
        nice = int(f[16])
        threads = int(f[17])
        start = int(f[19])
        statm = read(base + "/statm").split()
        rss = (int(statm[1]) - int(statm[2])) * PAGE if len(statm) > 2 else 0
        uid = os.stat(base).st_uid
        cmd = (read(base + "/cmdline").replace("\0", " ").strip() or f"[{name}]")[:240]
        io_r = io_w = None
        if uid == MY_UID:
            for line in read(base + "/io").splitlines():
                if line.startswith("read_bytes"):
                    io_r = int(line.split()[1])
                elif line.startswith("write_bytes"):
                    io_w = int(line.split()[1])
        return dict(pid=pid, ppid=ppid, name=name, cmd=cmd, uid=uid, state=state, nice=nice,
                    ticks=ticks, threads=threads, start=start, rss=max(rss, 0), io_r=io_r, io_w=io_w)
    except (OSError, ValueError, IndexError):
        return None

_win_cache = (0, [])
def windows():
    global _win_cache
    now = time.time()
    if now - _win_cache[0] < 2:
        return _win_cache[1]
    wins = []
    try:
        out = subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True, timeout=2).stdout
        for c in json.loads(out):
            if c.get("mapped", True):
                wins.append(dict(pid=c["pid"], cls=c.get("class", ""), title=c.get("title", ""),
                                 address=c.get("address", ""), ws=c.get("workspace", {}).get("name", "")))
    except Exception:
        pass
    _win_cache = (now, wins)
    return wins

_gpu_cache = (0, None)
def gpu():
    global _gpu_cache
    now = time.time()
    if now - _gpu_cache[0] < 2:
        return _gpu_cache[1]
    info = None
    if shutil.which("nvidia-smi"):
        try:
            out = subprocess.run(["nvidia-smi", "--query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,clocks.gr",
                                  "--format=csv,noheader,nounits"], capture_output=True, text=True, timeout=3).stdout.strip()
            p = [x.strip() for x in out.split(",")]
            num = lambda s: float(s) if s.replace(".", "", 1).isdigit() else None
            info = dict(name=p[0], util=num(p[1]), mem_used=(num(p[2]) or 0) * 1048576, mem_total=(num(p[3]) or 0) * 1048576,
                        temp=num(p[4]), power=num(p[5]), clock=num(p[6]))
        except Exception:
            info = None
    _gpu_cache = (now, info)
    return info

def drm_clients(pid):
    """Per-client DRM engine busy time (ns) from /proc/PID/fdinfo (i915/xe/amdgpu expose it)."""
    res = {}
    try:
        fds = os.listdir(f"/proc/{pid}/fd")
    except OSError:
        return res
    for fd in fds:
        try:
            if not os.readlink(f"/proc/{pid}/fd/{fd}").startswith("/dev/dri/"):
                continue
        except OSError:
            continue
        cid = pdev = None; eng = {}; cap = {}
        for line in read(f"/proc/{pid}/fdinfo/{fd}").splitlines():
            k, _, v = line.partition(":")
            v = v.strip()
            if k == "drm-client-id":
                cid = v
            elif k == "drm-pdev":
                pdev = v
            elif k.startswith("drm-engine-capacity-"):
                cap[k[20:]] = int(v) if v.isdigit() else 1
            elif k.startswith("drm-engine-") and v.endswith(" ns"):
                eng[k[11:]] = int(v[:-3])
        if cid and eng:
            res[(pdev, cid)] = {e: (ns, cap.get(e, 1)) for e, ns in eng.items()}
    return res

def igpu_name():
    try:
        out = subprocess.run(["lspci", "-mm", "-d", "8086::0300"], capture_output=True, text=True, timeout=2).stdout
        for line in out.splitlines():
            p = [x.strip('"') for x in line.split('" "')]
            if len(p) >= 3:
                n = p[2]
                return "Intel " + n[n.find("[") + 1:n.find("]")] if "[" in n else "Intel " + n
    except Exception:
        pass
    return "Intel GPU" if os.path.exists("/sys/module/i915") else None

def temps():
    res = {}
    for h in os.listdir("/sys/class/hwmon"):
        n = read(f"/sys/class/hwmon/{h}/name").strip()
        v = read(f"/sys/class/hwmon/{h}/temp1_input").strip()
        if n in ("coretemp", "k10temp") and v.isdigit():
            res["cpu"] = int(v) / 1000
    return res

def main():
    prev = dict(t=time.time(), cpu={n: (tot, idle) for n, tot, idle in cpu_times()}, procs={}, net=net_bytes(), disk=disk_bytes())
    boot = float(read("/proc/uptime").split()[0])
    static = dict(cpu_name=cpu_name(), ncpu=NCPU, hostname=read("/etc/hostname").strip(),
                  kernel=os.uname().release, uid=MY_UID, user=user_of(MY_UID), igpu=igpu_name(), clk=CLK, rootdev=_root_disk())
    prev_drm = {}
    first = True
    while True:
        time.sleep(0.25 if first else INTERVAL)
        now = time.time(); dt = max(now - prev["t"], 0.001)

        # CPU
        cur = {n: (tot, idle) for n, tot, idle in cpu_times()}
        usage = {}
        for n, (tot, idle) in cur.items():
            ptot, pidle = prev["cpu"].get(n, (tot, idle))
            d = tot - ptot
            usage[n] = round(100.0 * (d - (idle - pidle)) / d, 1) if d > 0 else 0.0
        total_cpu = usage.pop("cpu", 0.0)
        cores = [usage[k] for k in sorted((k for k in usage), key=lambda s: int(s[3:]))]

        # processes
        procs = {}
        for e in os.listdir("/proc"):
            if e.isdigit():
                p = read_proc(int(e))
                if p:
                    procs[p["pid"]] = p
        total_threads = 0
        for pid, p in procs.items():
            old = prev["procs"].get(pid)
            total_threads += p["threads"]
            if old and old["start"] == p["start"]:
                p["cpu"] = round(100.0 * (p["ticks"] - old["ticks"]) / CLK / dt / NCPU, 1)
                p["disk_r"] = max(0, (p["io_r"] - old["io_r"]) / dt) if p["io_r"] is not None and old["io_r"] is not None else None
                p["disk_w"] = max(0, (p["io_w"] - old["io_w"]) / dt) if p["io_w"] is not None and old["io_w"] is not None else None
            else:
                p["cpu"] = 0.0; p["disk_r"] = p["disk_w"] = None

        # GPU per process (own processes only, real DRM fdinfo counters)
        cur_drm = {}; seen_clients = set(); engine_tot = {}
        for pid, p in procs.items():
            p["gpu"] = None
            if p["uid"] != MY_UID:
                continue
            cl = drm_clients(pid)
            if not cl:
                continue
            cur_drm[(pid, p["start"])] = cl
            old = prev_drm.get((pid, p["start"]), {})
            best = 0.0
            for key, engs in cl.items():
                if key in seen_clients or key not in old:
                    continue
                seen_clients.add(key)
                for e, (ns, cap) in engs.items():
                    pns = old[key].get(e, (ns, cap))[0]
                    u = max(0.0, (ns - pns) / (dt * 1e9) / max(cap, 1) * 100)
                    engine_tot[e] = engine_tot.get(e, 0.0) + u
                    best = max(best, u)
            p["gpu"] = round(min(best, 100.0), 1)
        prev_drm = cur_drm
        igpu = dict(name=static["igpu"], util=round(min(100.0, max(engine_tot.values())), 1) if engine_tot else 0.0) if static["igpu"] else None

        # grouping: windows -> app group (all descendants of the window's pid)
        wins = windows()
        win_by_pid = {}
        for w in wins:
            win_by_pid.setdefault(w["pid"], w)
        def owner(pid):
            seen = 0
            while pid in procs and seen < 64:
                if pid in win_by_pid:
                    return pid
                pid = procs[pid]["ppid"]; seen += 1
            return None
        out_procs = []
        for pid, p in procs.items():
            if pid == os.getpid():
                continue
            o = owner(pid)
            kind = "app" if o else ("kernel" if p["ppid"] == 2 or pid == 2 else ("system" if p["uid"] == 0 else "background"))
            out_procs.append(dict(pid=pid, ppid=p["ppid"], name=p["name"], cmd=p["cmd"], user=user_of(p["uid"]), state=p["state"],
                                  cpu=p["cpu"], mem=p["rss"], threads=p["threads"], disk_r=p["disk_r"], disk_w=p["disk_w"],
                                  nice=p["nice"], cputime=round(p["ticks"] / CLK, 1), started=round(p["start"] / CLK, 1),
                                  gpu=p["gpu"], kind=kind, group=o))

        # memory / net / disk
        mi = meminfo()
        mem = dict(total=mi.get("MemTotal", 0), avail=mi.get("MemAvailable", 0), cached=mi.get("Cached", 0) + mi.get("Buffers", 0),
                   used=mi.get("MemTotal", 0) - mi.get("MemAvailable", 0), swap_total=mi.get("SwapTotal", 0),
                   swap_used=mi.get("SwapTotal", 0) - mi.get("SwapFree", 0))
        nb = net_bytes()
        net = {k: dict(rx=max(0, (v[0] - prev["net"].get(k, v)[0]) / dt), tx=max(0, (v[1] - prev["net"].get(k, v)[1]) / dt),
                       rx_total=v[0], tx_total=v[1], up=read(f"/sys/class/net/{k}/operstate").strip() == "up") for k, v in nb.items()}
        db = disk_bytes()
        disk = {k: dict(read=max(0, (v[0] - prev["disk"].get(k, v)[0]) / dt), write=max(0, (v[1] - prev["disk"].get(k, v)[1]) / dt),
                        busy=min(100.0, max(0.0, (v[2] - prev["disk"].get(k, v)[2]) / (dt * 10.0)))) for k, v in db.items()}
        st = os.statvfs("/")
        root = dict(total=st.f_blocks * st.f_frsize, free=st.f_bavail * st.f_frsize)

        print(json.dumps(dict(
            t=now, uptime=float(read("/proc/uptime").split()[0]), static=static,
            cpu=dict(total=total_cpu, cores=cores, freq=cpu_freq(), procs=len(procs), threads=total_threads, temp=temps().get("cpu")),
            mem=mem, net=net, disk=disk, root=root, gpu=gpu(), igpu=igpu, procs=out_procs, wins=wins,
            rootdev=static["rootdev"],
            load=read("/proc/loadavg").split()[:3]), separators=(",", ":")), flush=True)
        prev = dict(t=now, cpu=cur, procs=procs, net=nb, disk=db)
        first = False

if __name__ == "__main__":
    try:
        main()
    except (BrokenPipeError, KeyboardInterrupt):
        pass
