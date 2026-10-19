#!/usr/bin/env python3
"""Операции «Диспетчера файлов» Serpantinum. Вывод — одна строка JSON.

  paste copy|move DEST PATH...   копирование/перемещение (при совпадении имён — «имя (2).ext»)
  trash PATH...                  в корзину (gio trash, стандарт freedesktop)
  delete PATH...                 удалить навсегда
  mkdir DIR NAME | touch DIR NAME  создать папку / пустой файл (имя делается уникальным)
  rename PATH NEWNAME
  info PATH                      дата создания, теги и примечание (xattr user.xdg.tags / user.xdg.comment), размер папки
  settags PATH "a,b"  |  setnote PATH TEXT
  drives                         смонтированные диски (df) + неподключённые съёмные разделы (lsblk)
  mount DEV | eject DEV          подключить / извлечь съёмный диск (udisksctl, без root)
  trashlist | restore NAME... | emptytrash
  search ROOT QUERY              рекурсивный поиск по имени (fd)
  recent [N]                     недавние файлы (~/.local/share/recently-used.xbel)
"""
import json, os, shutil, subprocess, sys, urllib.parse

def out(o):
    print(json.dumps(o, ensure_ascii=False), flush=True)

def unique(dest_dir, name):
    base, ext = os.path.splitext(name)
    if os.path.isdir(os.path.join(dest_dir, name)):
        base, ext = name, ""
    cand, n = name, 2
    while os.path.lexists(os.path.join(dest_dir, cand)):
        cand = f"{base} ({n}){ext}"; n += 1
    return cand

def xattr_get(path, key):
    try:
        return os.getxattr(path, key).decode("utf-8", "replace")
    except OSError:
        return ""

def dir_size(path, limit=20000):
    total = count = 0
    for root, dirs, files in os.walk(path):
        for f in files:
            try:
                total += os.lstat(os.path.join(root, f)).st_size
            except OSError:
                pass
            count += 1
            if count > limit:
                return total, True
    return total, False

def stat_items(paths):
    res = []
    for p in paths:
        try:
            st = os.stat(p)
            res.append({"path": p, "name": os.path.basename(p), "isdir": os.path.isdir(p), "size": st.st_size, "modified": int(st.st_mtime)})
        except OSError:
            pass
    return res

def main():
    a = sys.argv[1:]
    if not a:
        return out({"ok": False, "error": "нет команды"})
    cmd = a[0]
    try:
        if cmd == "paste":
            mode, dest, paths = a[1], a[2], a[3:]
            done = []
            for p in paths:
                p = p.rstrip("/")
                if not os.path.lexists(p):
                    continue
                name = os.path.basename(p)
                if mode == "move" and os.path.dirname(os.path.abspath(p)) == os.path.abspath(dest):
                    continue                                   # вставка на то же место — ничего не делать
                if os.path.isdir(p) and os.path.abspath(dest).startswith(os.path.abspath(p) + "/"):
                    return out({"ok": False, "error": "Нельзя скопировать папку внутрь самой себя"})
                target = os.path.join(dest, unique(dest, name))
                if mode == "move":
                    shutil.move(p, target)
                elif os.path.isdir(p) and not os.path.islink(p):
                    shutil.copytree(p, target, symlinks=True)
                else:
                    shutil.copy2(p, target, follow_symlinks=False)
                done.append(target)
            return out({"ok": True, "paths": done})
        if cmd == "trash":
            r = subprocess.run(["gio", "trash", "--"] + a[1:], capture_output=True, text=True)
            return out({"ok": r.returncode == 0, "error": r.stderr.strip()})
        if cmd == "delete":
            for p in a[1:]:
                if os.path.isdir(p) and not os.path.islink(p):
                    shutil.rmtree(p)
                else:
                    os.remove(p)
            return out({"ok": True})
        if cmd in ("mkdir", "touch"):
            d, name = a[1], a[2]
            target = os.path.join(d, unique(d, name))
            if cmd == "mkdir":
                os.mkdir(target)
            else:
                open(target, "x").close()
            return out({"ok": True, "path": target})
        if cmd == "rename":
            p, new = a[1].rstrip("/"), a[2]
            if "/" in new or new in ("", ".", ".."):
                return out({"ok": False, "error": "Недопустимое имя"})
            target = os.path.join(os.path.dirname(p), new)
            if os.path.lexists(target):
                return out({"ok": False, "error": "Файл с таким именем уже существует"})
            os.rename(p, target)
            return out({"ok": True, "path": target})
        if cmd == "info":
            p = a[1]
            st = os.lstat(p)
            r = subprocess.run(["stat", "-c", "%W", p], capture_output=True, text=True)
            born = int(r.stdout.strip() or 0)
            o = {"ok": True, "created": born if born > 0 else None, "modified": int(st.st_mtime),
                 "tags": [t for t in xattr_get(p, "user.xdg.tags").split(",") if t.strip()],
                 "note": xattr_get(p, "user.xdg.comment"), "size": st.st_size, "isdir": os.path.isdir(p)}
            if o["isdir"]:
                o["size"], o["partial"] = dir_size(p)
            return out(o)
        if cmd == "settags":
            p, tags = a[1], ",".join(t.strip() for t in a[2].split(",") if t.strip())
            if tags:
                os.setxattr(p, "user.xdg.tags", tags.encode())
            else:
                try: os.removexattr(p, "user.xdg.tags")
                except OSError: pass
            return out({"ok": True})
        if cmd == "setnote":
            p, note = a[1], a[2]
            if note.strip():
                os.setxattr(p, "user.xdg.comment", note.encode())
            else:
                try: os.removexattr(p, "user.xdg.comment")
                except OSError: pass
            return out({"ok": True})
        if cmd == "drives":
            r = subprocess.run(["df", "-B1", "--output=source,fstype,size,used,avail,target"], capture_output=True, text=True)
            seen, res = set(), []
            for line in r.stdout.splitlines()[1:]:
                f = line.split(None, 5)
                if len(f) < 6 or not f[0].startswith("/dev/") or f[0] in seen:
                    continue
                if f[5].startswith(("/boot", "/efi", "/var", "/.snapshots", "/srv", "/opt", "/root", "/tmp")):
                    continue
                seen.add(f[0])
                res.append({"dev": f[0], "fs": f[1], "size": int(f[2]), "used": int(f[3]), "avail": int(f[4]), "mount": f[5]})
            # съёмные (USB, SD): помечаем смонтированные и добавляем неподключённые
            r = subprocess.run(["lsblk", "-J", "-b", "-p", "-o", "PATH,FSTYPE,LABEL,SIZE,RM,HOTPLUG,TRAN,MOUNTPOINT"], capture_output=True, text=True)
            def walk(nodes, removable=False):
                for n in nodes:
                    rem = removable or bool(n.get("rm")) or bool(n.get("hotplug")) or n.get("tran") == "usb"
                    yield n, rem
                    yield from walk(n.get("children") or [], rem)
            for n, rem in walk(json.loads(r.stdout or "{}").get("blockdevices", [])):
                if not rem or not n.get("fstype") or n["fstype"] in ("swap", "crypto_LUKS"):
                    continue
                d = next((x for x in res if x["dev"] == n["path"]), None)
                if d:
                    d["removable"], d["label"] = True, n.get("label") or ""
                elif not n.get("mountpoint"):
                    res.append({"dev": n["path"], "fs": n["fstype"], "size": int(n.get("size") or 0), "used": 0, "avail": 0,
                                "mount": "", "label": n.get("label") or "", "removable": True})
            return out({"ok": True, "drives": res})
        if cmd == "mount":
            r = subprocess.run(["udisksctl", "mount", "-b", a[1], "--no-user-interaction"], capture_output=True, text=True)
            if r.returncode != 0 and "AlreadyMounted" not in r.stderr:
                return out({"ok": False, "error": r.stderr.strip()})
            m = subprocess.run(["lsblk", "-no", "MOUNTPOINT", a[1]], capture_output=True, text=True).stdout.strip()
            return out({"ok": bool(m), "mount": m})
        if cmd == "eject":
            subprocess.run(["sync"])
            r = subprocess.run(["udisksctl", "unmount", "-b", a[1], "--no-user-interaction"], capture_output=True, text=True)
            if r.returncode != 0 and "NotMounted" not in r.stderr:
                return out({"ok": False, "error": "Диск занят: закройте открытые с него файлы" if "busy" in r.stderr.lower() else r.stderr.strip()})
            disk = subprocess.run(["lsblk", "-no", "PKNAME", "-p", a[1]], capture_output=True, text=True).stdout.strip() or a[1]
            subprocess.run(["udisksctl", "power-off", "-b", disk, "--no-user-interaction"], capture_output=True, text=True)
            return out({"ok": True})
        if cmd == "trashlist":
            base = os.path.expanduser("~/.local/share/Trash")
            items = []
            if os.path.isdir(base + "/files"):
                for n in os.listdir(base + "/files"):
                    info = {}
                    try:
                        for line in open(f"{base}/info/{n}.trashinfo", encoding="utf-8"):
                            k, _, v = line.strip().partition("=")
                            info[k] = v
                    except OSError:
                        pass
                    p = f"{base}/files/{n}"
                    st = os.lstat(p)
                    items.append({"name": n, "path": p, "orig": urllib.parse.unquote(info.get("Path", "")),
                                  "deleted": info.get("DeletionDate", ""), "isdir": os.path.isdir(p),
                                  "size": st.st_size, "modified": int(st.st_mtime)})
            return out({"ok": True, "items": items})
        if cmd == "restore":
            base = os.path.expanduser("~/.local/share/Trash")
            for n in a[1:]:
                info = {}
                for line in open(f"{base}/info/{n}.trashinfo", encoding="utf-8"):
                    k, _, v = line.strip().partition("=")
                    info[k] = v
                orig = urllib.parse.unquote(info["Path"])
                d = os.path.dirname(orig)
                os.makedirs(d, exist_ok=True)
                shutil.move(f"{base}/files/{n}", os.path.join(d, unique(d, os.path.basename(orig))))
                os.remove(f"{base}/info/{n}.trashinfo")
            return out({"ok": True})
        if cmd == "emptytrash":
            r = subprocess.run(["gio", "trash", "--empty"], capture_output=True, text=True)
            return out({"ok": r.returncode == 0, "error": r.stderr.strip()})
        if cmd == "search":
            root, q = a[1], a[2]
            r = subprocess.run(["fd", "--hidden", "--exclude", ".git", "--ignore-case", "--max-results", "500", "--fixed-strings", q, root],
                               capture_output=True, text=True, timeout=30)
            return out({"ok": True, "items": stat_items([p.rstrip("/") for p in r.stdout.splitlines()])})
        if cmd == "recent":
            import xml.etree.ElementTree as ET
            n = int(a[1]) if len(a) > 1 else 30
            items = []
            try:
                for b in ET.parse(os.path.expanduser("~/.local/share/recently-used.xbel")).getroot().iter("bookmark"):
                    href = b.get("href", "")
                    if not href.startswith("file://"):
                        continue
                    p = urllib.parse.unquote(href[7:])
                    if os.path.isfile(p):
                        items.append((b.get("visited") or b.get("modified") or "", p))
            except (OSError, ET.ParseError):
                pass
            items.sort(reverse=True)
            seen, res = set(), []
            for _, p in items:
                if p not in seen:
                    seen.add(p); res.append(p)
            return out({"ok": True, "items": stat_items(res[:n])})
        if cmd == "stat":                                       # для результатов поиска/недавних
            res = []
            for p in a[1:]:
                try:
                    st = os.stat(p)
                    res.append({"path": p, "isdir": os.path.isdir(p), "size": st.st_size, "modified": int(st.st_mtime)})
                except OSError:
                    pass
            return out({"ok": True, "items": res})
        return out({"ok": False, "error": "неизвестная команда " + cmd})
    except Exception as e:
        return out({"ok": False, "error": str(e)})

if __name__ == "__main__":
    main()
