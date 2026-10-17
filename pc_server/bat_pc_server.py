#!/usr/bin/env python3
"""
BATMAN PC Server
Pequeño servidor para que la app BATMAN Mobile vea el estado de tu PC y lance
tareas PERMITIDAS. No existe ningún endpoint para ejecutar comandos libres:
solo se pueden lanzar las tareas listadas en bat_pc_config.json.

Seguridad:
  - Todas las rutas (menos /ping) exigen el token (cabecera Authorization: Bearer ...).
  - Úsalo solo en tu red Wi-Fi de casa. No abras el puerto en tu router.
  - Para usarlo fuera de casa, instala Tailscale (VPN privada) en PC y celular.
"""
import hmac
import json
import os
import platform
import secrets
import shutil
import socket
import subprocess
import sys
import tempfile
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

try:
    import psutil
except ImportError:
    psutil = None

BASE = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.environ.get("BAT_CONFIG", os.path.join(BASE, "bat_pc_config.json"))

DEFAULT_TASKS = [
    {"id": "limpiar_temp", "label": "Limpiar archivos temporales (más de 24 h)", "builtin": "clean_temp"},
    {"id": "dns", "label": "Vaciar caché DNS", "cmd": ["ipconfig", "/flushdns"]},
    {"id": "bloquear", "label": "Bloquear la PC", "cmd": ["rundll32.exe", "user32.dll,LockWorkStation"]},
    {"id": "apagar", "label": "Apagar la PC (en 30 s)", "cmd": ["shutdown", "/s", "/t", "30"], "confirm": True},
    {"id": "cancelar_apagado", "label": "Cancelar apagado", "cmd": ["shutdown", "/a"]},
]


def load_config():
    if not os.path.exists(CONFIG_PATH):
        cfg = {"host": "0.0.0.0", "port": 8765, "token": secrets.token_urlsafe(18), "tasks": DEFAULT_TASKS}
        with open(CONFIG_PATH, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2, ensure_ascii=False)
        return cfg
    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        cfg = json.load(f)
    if not cfg.get("token"):
        cfg["token"] = secrets.token_urlsafe(18)
        with open(CONFIG_PATH, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2, ensure_ascii=False)
    cfg.setdefault("host", "0.0.0.0")
    cfg.setdefault("port", 8765)
    cfg.setdefault("tasks", DEFAULT_TASKS)
    return cfg


CFG = load_config()


def visible_tasks():
    out = []
    for t in CFG["tasks"]:
        req = t.get("requires_file")
        if req and not os.path.exists(req):
            continue
        out.append(t)
    return out


def status():
    data = {"host": socket.gethostname(), "os": platform.system() + " " + platform.release()}
    root = os.path.abspath(os.sep)
    if psutil is None:
        du = shutil.disk_usage(root)
        data["disk"] = round(du.used * 100 / du.total, 1)
        data["disk_free_gb"] = round(du.free / 1e9, 1)
        data["note"] = "Instala psutil (python -m pip install psutil) para ver CPU, RAM y batería."
        return data
    data["cpu"] = psutil.cpu_percent(interval=0.3)
    vm = psutil.virtual_memory()
    data["ram"] = vm.percent
    data["ram_used_gb"] = round(vm.used / 1e9, 1)
    data["ram_total_gb"] = round(vm.total / 1e9, 1)
    du = psutil.disk_usage(root)
    data["disk"] = du.percent
    data["disk_free_gb"] = round(du.free / 1e9, 1)
    try:
        b = psutil.sensors_battery()
        if b is not None:
            data["battery"] = round(b.percent)
            data["plugged"] = bool(b.power_plugged)
    except Exception:
        pass
    data["uptime_h"] = round((time.time() - psutil.boot_time()) / 3600, 1)
    totals = {}
    for p in psutil.process_iter(["name", "memory_info"]):
        try:
            mi = p.info["memory_info"]
            name = p.info["name"] or "?"
            totals[name] = totals.get(name, 0) + (mi.rss if mi else 0)
        except Exception:
            pass
    top = sorted(totals.items(), key=lambda kv: kv[1], reverse=True)[:5]
    data["top"] = [{"name": n, "mem_mb": round(r / 1048576)} for n, r in top]
    return data


def clean_temp():
    tmp = tempfile.gettempdir()
    cutoff = time.time() - 86400
    removed = 0
    freed = 0
    for root, dirs, files in os.walk(tmp, topdown=False):
        for f in files:
            path = os.path.join(root, f)
            try:
                st = os.stat(path)
                if st.st_mtime < cutoff:
                    os.remove(path)
                    removed += 1
                    freed += st.st_size
            except OSError:
                pass
        for d in dirs:
            try:
                os.rmdir(os.path.join(root, d))  # solo si está vacía
            except OSError:
                pass
    return "Temporales limpiados: %d archivos, %.1f MB liberados." % (removed, freed / 1048576)


def run_task(task):
    if task.get("builtin") == "clean_temp":
        return True, clean_temp()
    cmd = task.get("cmd")
    if not cmd:
        return False, "La tarea no tiene comando."
    try:
        if task.get("detached"):
            flags = 0x00000008 | 0x00000200 if os.name == "nt" else 0
            subprocess.Popen(cmd, creationflags=flags, close_fds=True)
            return True, "Lanzado en la PC."
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        out = (r.stdout or r.stderr or "").strip()
        ok = r.returncode == 0
        if len(out) > 400:
            out = out[:400] + "…"
        return ok, out or ("Listo." if ok else "La tarea falló.")
    except FileNotFoundError:
        return False, "Comando no encontrado en esta PC."
    except subprocess.TimeoutExpired:
        return False, "La tarea tardó demasiado y se canceló."
    except Exception as e:  # noqa: BLE001
        return False, "Error: %s" % e


class Handler(BaseHTTPRequestHandler):
    server_version = "BatPC/1.0"

    def log_message(self, fmt, *args):
        sys.stdout.write("[%s] %s\n" % (time.strftime("%H:%M:%S"), fmt % args))

    def _send(self, code, obj):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _authorized(self):
        header = self.headers.get("Authorization", "")
        token = header[7:] if header.startswith("Bearer ") else ""
        return hmac.compare_digest(token.encode("utf-8"), CFG["token"].encode("utf-8"))

    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/ping":
            return self._send(200, {"ok": True})
        if not self._authorized():
            time.sleep(0.5)
            return self._send(401, {"error": "token incorrecto"})
        if path == "/status":
            return self._send(200, status())
        if path == "/tasks":
            return self._send(
                200, [{"id": t["id"], "label": t.get("label", t["id"]), "confirm": bool(t.get("confirm"))} for t in visible_tasks()]
            )
        return self._send(404, {"error": "no existe"})

    def do_POST(self):
        path = self.path.split("?")[0]
        if not self._authorized():
            time.sleep(0.5)
            return self._send(401, {"error": "token incorrecto"})
        if path != "/run":
            return self._send(404, {"error": "no existe"})
        try:
            length = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(min(length, 4096)) or b"{}")
        except (ValueError, json.JSONDecodeError):
            return self._send(400, {"error": "petición inválida"})
        task = next((t for t in visible_tasks() if t["id"] == payload.get("task")), None)
        if task is None:
            return self._send(404, {"ok": False, "message": "Tarea no permitida."})
        ok, message = run_task(task)
        print("Tarea %s -> %s" % (task["id"], "ok" if ok else "falló"))
        return self._send(200, {"ok": ok, "message": message})


def local_ips():
    ips = set()
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ips.add(s.getsockname()[0])
        s.close()
    except OSError:
        pass
    try:
        for info in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
            ips.add(info[4][0])
    except OSError:
        pass
    return sorted(i for i in ips if not i.startswith("127."))


def main():
    server = ThreadingHTTPServer((CFG["host"], int(CFG["port"])), Handler)
    print("=" * 60)
    print(" BATMAN PC Server activo")
    print(" Pega esto en la app BATMAN (Ajustes > Tu PC):")
    for ip in local_ips() or ["<IP-de-tu-PC>"]:
        print("   Dirección: %s:%s" % (ip, CFG["port"]))
    print("   Token:     %s" % CFG["token"])
    print(" Solo en tu Wi-Fi de casa. Cierra esta ventana para detenerlo.")
    if psutil is None:
        print(" AVISO: falta psutil. Ejecuta:  python -m pip install psutil")
    print("=" * 60)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
