#!/usr/bin/env python3
"""UDP presence beacon for Quake deathmatch (Tailscale or LAN).

Protocol (UTF-8, one datagram):
  QUAKE-OMARCHY/1 PING
  QUAKE-OMARCHY/1 PONG <json>
"""
from __future__ import annotations

import argparse
import json
import select
import socket
import sys
import time

PREFIX = "QUAKE-OMARCHY/1"
DEFAULT_PORT = 26001
TIMEOUT = 0.8
PING = f"{PREFIX} PING".encode("utf-8")


def serve(payload: dict, port: int) -> None:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(("0.0.0.0", port))
    body = json.dumps(payload, separators=(",", ":"))
    reply = f"{PREFIX} PONG {body}".encode("utf-8")
    while True:
        data, addr = sock.recvfrom(2048)
        text = data.decode("utf-8", "replace").strip()
        if text.startswith(f"{PREFIX} PING"):
            sock.sendto(reply, addr)


def _parse_pong(data: bytes, src_ip: str) -> dict | None:
    text = data.decode("utf-8", "replace").strip()
    marker = f"{PREFIX} PONG "
    if not text.startswith(marker):
        return None
    try:
        payload = json.loads(text[len(marker) :])
    except json.JSONDecodeError:
        return None
    if not isinstance(payload, dict):
        return None
    # A host that could not work out its own address advertises "" — use the
    # address the reply actually came from.
    if not payload.get("ip"):
        payload["ip"] = src_ip
    if not payload.get("join"):
        payload["join"] = "%s:%s" % (payload["ip"], payload.get("port") or 26000)
    return payload


def ping(host: str, port: int, timeout: float) -> dict | None:
    found = ping_many([host], port, timeout)
    return found[0] if found else None


def ping_many(hosts: list[str], port: int, timeout: float, exclude: list[str] | None = None) -> list[dict]:
    """Send every ping at once, then collect PONG replies until timeout."""
    skip = {h.strip() for h in (exclude or []) if h and h.strip()}
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.setblocking(False)
    sent = 0
    for host in hosts:
        host = (host or "").strip()
        if not host or host in skip:
            continue
        try:
            sock.sendto(PING, (host, port))
            sent += 1
        except OSError:
            continue
    if sent == 0:
        sock.close()
        return []
    deadline = time.time() + max(0.2, timeout)
    found: list[dict] = []
    seen: set[str] = set()
    while True:
        remaining = deadline - time.time()
        if remaining <= 0:
            break
        readable, _, _ = select.select([sock], [], [], remaining)
        if not readable:
            break
        try:
            data, addr = sock.recvfrom(4096)
        except OSError:
            break
        ip = addr[0]
        if ip in skip or ip in seen:
            continue
        payload = _parse_pong(data, ip)
        if payload is None:
            continue
        seen.add(ip)
        found.append(payload)
    sock.close()
    return found


def main() -> int:
    parser = argparse.ArgumentParser(prog="omarchy-quake-beacon")
    sub = parser.add_subparsers(dest="cmd", required=True)

    serve_p = sub.add_parser("serve")
    serve_p.add_argument("--port", type=int, default=DEFAULT_PORT)
    serve_p.add_argument("--payload", required=True, help="JSON object advertised to pingers")

    ping_p = sub.add_parser("ping")
    ping_p.add_argument("hosts", nargs="*")
    ping_p.add_argument("--port", type=int, default=DEFAULT_PORT)
    ping_p.add_argument("--timeout", type=float, default=TIMEOUT)
    ping_p.add_argument("--exclude", action="append", default=[], help="Skip this IP (repeatable)")

    args = parser.parse_args()
    if args.cmd == "serve":
        payload = json.loads(args.payload)
        payload.setdefault("started_at", int(time.time()))
        serve(payload, args.port)
        return 0

    hosts = list(args.hosts)
    if not hosts:
        json.dump([], sys.stdout)
        sys.stdout.write("\n")
        return 0
    exclude: list[str] = []
    for item in args.exclude:
        exclude.extend(item.replace(",", " ").split())
    results = ping_many(hosts, args.port, args.timeout, exclude=exclude)
    json.dump(results, sys.stdout)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
