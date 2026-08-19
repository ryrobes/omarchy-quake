#!/usr/bin/env python3
"""NetQuake control packets for a local vkQuake listen server (rcon / status).

vkQuake speaks NetQuake, not QuakeWorld. There is no QW `getstatus` unless
`sv_public 1` is set; the reliable hook is CCREQ_RCON (0x05) against the
listen port, which runs console commands and returns Con_Printf output.
`status` is Host_Status_f; `changelevel` keeps connected clients.
"""
from __future__ import annotations

import argparse
import json
import re
import socket
import struct
import sys

NETFLAG_CTL = 0x80000000
CCREQ_RCON = 0x05
CCREP_RCON = 0x86

RCON_ERROR_MARKERS = (
    "rcon is not enabled",
    "Your password is just WRONG",
    "What, you really thought",
    "Oh look! You found the backdoor",
)


class RconError(Exception):
    pass


def _qstr(s: str) -> bytes:
    return s.encode("latin-1", "replace") + b"\x00"


def rcon(host: str, port: int, password: str, command: str, timeout: float = 1.2) -> str:
    body = bytes([CCREQ_RCON]) + _qstr(password) + _qstr(command)
    total = 4 + len(body)
    packet = struct.pack(">I", NETFLAG_CTL | (total & 0xFFFF)) + body
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(timeout)
    try:
        sock.sendto(packet, (host, port))
        data, _ = sock.recvfrom(8192)
    except OSError as exc:
        raise RconError(f"rcon failed: {exc}") from exc
    finally:
        sock.close()
    if len(data) < 6:
        raise RconError("rcon: short reply")
    cmd = data[4]
    if cmd != CCREP_RCON:
        raise RconError(f"rcon: unexpected reply {cmd:#x}")
    return data[5:].split(b"\x00", 1)[0].decode("latin-1", "replace")


def parse_status(text: str) -> dict:
    info: dict = {
        "ok": True,
        "host": "",
        "map": "",
        "players": 0,
        "max": 0,
        "clients": [],
    }
    stripped = (text or "").strip()
    for marker in RCON_ERROR_MARKERS:
        if marker in stripped:
            info["ok"] = False
            info["error"] = stripped
            return info
    # Host_Status_f:
    #   host:    name
    #   map:     e1m2
    #   players: N active (M max)
    #   #%-2u %-16.16s  %3i  %2i:%02i:%02i
    player_re = re.compile(r"^#(\d+)\s+(.+?)\s+(-?\d+)\s+(\d+:\d+:\d+)\s*$")
    for line in text.splitlines():
        if line.startswith("host:"):
            info["host"] = line.split(":", 1)[1].strip()
        elif line.startswith("map:"):
            info["map"] = line.split(":", 1)[1].strip()
        elif line.startswith("players:"):
            m = re.search(r"(\d+)\s+active\s+\((\d+)\s+max\)", line)
            if m:
                info["players"] = int(m.group(1))
                info["max"] = int(m.group(2))
        else:
            m = player_re.match(line)
            if m:
                info["clients"].append(
                    {
                        "slot": int(m.group(1)),
                        "name": m.group(2).strip(),
                        "frags": int(m.group(3)),
                        "time": m.group(4),
                    }
                )
    return info


def _emit_json(payload: dict, ok: bool) -> int:
    json.dump(payload, sys.stdout)
    sys.stdout.write("\n")
    return 0 if ok else 1


def main() -> int:
    p = argparse.ArgumentParser(prog="nqctl")
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", type=int, default=26000)
    p.add_argument("--password", required=True)
    p.add_argument("--json", action="store_true", help="always emit JSON (errors included)")
    p.add_argument("--timeout", type=float, default=1.2)
    p.add_argument("command", nargs="+")
    args = p.parse_args()
    cmd = " ".join(args.command)
    try:
        text = rcon(args.host, args.port, args.password, cmd, timeout=args.timeout)
    except RconError as exc:
        if args.json:
            return _emit_json({"ok": False, "error": str(exc)}, False)
        print(str(exc), file=sys.stderr)
        return 1
    if cmd.strip() == "status":
        info = parse_status(text)
        return _emit_json(info, bool(info.get("ok")))
    if args.json:
        return _emit_json({"ok": True, "text": text}, True)
    sys.stdout.write(text)
    if text and not text.endswith("\n"):
        sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
