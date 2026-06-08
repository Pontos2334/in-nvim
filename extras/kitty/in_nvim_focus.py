import os
import subprocess
from time import strftime


RUNTIME_DIR = "/tmp/in-nvim-kitty"
LOG_FILE = "/tmp/in-nvim-kitty.log"
CALLBACK_EXPR = "luaeval(\"require('in_nvim')._focus_gained()\")"


def _log(message):
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(f"{strftime('%Y-%m-%d %H:%M:%S')} {message}\n")
    except Exception:
        pass


def _candidate_window_ids(window):
    seen = set()

    def add(value):
        if value is None:
            return
        value = str(value)
        if value and value not in seen:
            seen.add(value)
            yield value

    yield from add(getattr(window, "id", None))

    child = getattr(window, "child", None)
    for attr in ("environ", "final_env", "foreground_environ"):
        env = getattr(child, attr, None) if child is not None else None
        if isinstance(env, dict):
            yield from add(env.get("KITTY_WINDOW_ID"))


def _server_for_window(window):
    for window_id in _candidate_window_ids(window):
        path = os.path.join(RUNTIME_DIR, window_id)
        try:
            with open(path, "r", encoding="utf-8") as f:
                server = f.readline().strip()
        except OSError:
            continue
        if server:
            return window_id, server
    return None, None


def on_focus_change(boss, window, data):
    if not data.get("focused"):
        return

    window_id, server = _server_for_window(window)
    if not server:
        return

    try:
        subprocess.Popen(
            ["nvim", "--server", server, "--remote-expr", CALLBACK_EXPR],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except Exception as e:
        _log(f"failed to call nvim server for window {window_id}: {e}")
