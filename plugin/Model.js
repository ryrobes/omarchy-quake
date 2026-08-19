.pragma library

function parseJson(text, fallback) {
  try {
    var value = JSON.parse(String(text || ""))
    return value === undefined || value === null ? fallback : value
  } catch (e) {
    return fallback
  }
}

function editionLabel(edition) {
  var key = String(edition || "auto")
  if (key === "rerelease" || key === "remaster" || key === "remastered") return "2021 re-release"
  if (key === "classic" || key === "original" || key === "registered") return "Registered / classic"
  if (key === "shareware") return "Shareware"
  return "Auto"
}

function editionMeta(source, status, editionCfg) {
  var edition = (source && source.edition) || (status && status.edition) || editionCfg || "auto"
  var label = editionLabel(edition)
  var where = source && source.where ? String(source.where) : ""
  var origin = source && source.origin ? String(source.origin) : ""
  if (origin === "download" || origin === "missing")
    return where || "will download shareware on launch"
  if (origin === "shareware")
    return "shareware"
  if (where)
    return label + " · " + where
  if (status && status.basedir)
    return label + " · " + originWhereFromPath(status.basedir)
  if (edition === "auto")
    return "will download shareware on launch"
  return label
}

function originWhereFromPath(path) {
  var p = String(path || "").toLowerCase()
  if (p.indexOf("steamapps") !== -1 || p.indexOf("steamlibrary") !== -1)
    return "found in Steam folder"
  if (p.indexOf("/gog") !== -1)
    return "found in GOG folder"
  if (p.indexOf("heroic") !== -1)
    return "found in Heroic folder"
  if (p.indexOf("shareware") !== -1)
    return "shareware"
  return "found on disk"
}

function modeLabel(status) {
  if (!status) return "Idle"
  if (status.error) return String(status.error)
  if (status.mode === "fetch") {
    var fetch = status.fetch || {}
    return fetch.message || "Downloading shareware"
  }
  if (status.running || status.alive) {
    if (status.mode === "host") return "Hosting deathmatch"
    if (status.mode === "join") return "Connected"
    return "Playing"
  }
  return "Ready"
}

function joinCommand(status) {
  var host = status && status.host
  if (!host) return ""
  if (host.command) return String(host.command)
  var target = host.join || ((host.dns || host.ip || "") + ":" + (host.port || 26000))
  if (!target || target.charAt(0) === ":") return ""
  return "omarchy-quake join " + target
}

function hostLine(status) {
  var cmd = joinCommand(status)
  if (cmd) return cmd
  var host = status && status.host
  if (!host) return ""
  var ip = host.ip || "this machine"
  var port = host.port || 26000
  var map = host.map || ""
  return ip + ":" + port + (map ? "  ·  " + map : "")
}

function peerLabel(peer) {
  if (!peer) return ""
  var name = peer.name || peer.ip || "unknown"
  var map = peer.map || "?"
  var ip = peer.ip || ""
  var port = peer.port || 26000
  return name + "  ·  " + map + "  ·  " + ip + ":" + port
}

function peerTarget(peer) {
  if (!peer) return ""
  if (peer.join) return String(peer.join)
  var host = peer.dns || peer.ip || ""
  if (!host) return ""
  return host + ":" + String(peer.port || 26000)
}

function parseConfig(text) {
  var out = {}
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (!line || line.charAt(0) === "#") continue
    var cut = line.indexOf("=")
    if (cut < 1) continue
    out[line.slice(0, cut)] = line.slice(cut + 1)
  }
  return out
}

function isTruthy(value) {
  var v = String(value || "").toLowerCase()
  return v === "true" || v === "1" || v === "yes" || v === "on"
}

function resolutionValue(cfg) {
  var w = parseInt(cfg && cfg.width ? cfg.width : "0", 10) || 0
  var h = parseInt(cfg && cfg.height ? cfg.height : "0", 10) || 0
  if (w > 0 && h > 0) return w + "x" + h
  return "native"
}

function resolutionOptions() {
  return [
    { value: "native", label: "Native (monitor)" },
    { value: "1920x1080", label: "1920 × 1080" },
    { value: "1600x900", label: "1600 × 900" },
    { value: "1280x720", label: "1280 × 720" },
    { value: "960x540", label: "960 × 540" },
    { value: "640x480", label: "640 × 480" }
  ]
}

function mapsFor(edition) {
  if (edition === "shareware")
    return ["e1m2", "e1m5", "e1m7", "e1m1", "start"]
  return ["e1m2", "dm1", "dm2", "dm3", "dm4", "dm6", "e1m5", "e1m7"]
}

// Classic Quake player colormap, indices 0–13 (shirt / pants).
function playerColors() {
  return [
    { value: 0, label: "White", hex: "#D0D0D0" },
    { value: 1, label: "Brown", hex: "#8B4A24" },
    { value: 2, label: "Slate", hex: "#5A5A8C" },
    { value: 3, label: "Green", hex: "#2A8C2A" },
    { value: 4, label: "Red", hex: "#B42828" },
    { value: 5, label: "Olive", hex: "#8C8C28" },
    { value: 6, label: "Orange", hex: "#E87820" },
    { value: 7, label: "Gold", hex: "#E8A030" },
    { value: 8, label: "Peach", hex: "#E0A090" },
    { value: 9, label: "Purple", hex: "#8C5098" },
    { value: 10, label: "Magenta", hex: "#602080" },
    { value: 11, label: "Tan", hex: "#A07850" },
    { value: 12, label: "Sage", hex: "#709050" },
    { value: 13, label: "Blue", hex: "#2850A0" }
  ]
}

function clampColor(value) {
  var n = parseInt(value, 10)
  if (isNaN(n) || n < 0) return 0
  if (n > 13) return 13
  return n
}

function colorEntry(value) {
  var colors = playerColors()
  var n = clampColor(value)
  return colors[n] || colors[0]
}

function colorHex(value) {
  return colorEntry(value).hex
}

function colorName(value) {
  return colorEntry(value).label
}

function hosting(status) {
  if (!status) return false
  if (!(status.running || status.alive)) return false
  return status.mode === "host"
}

function gameWindowMapped(raw) {
  var clients
  try { clients = JSON.parse(String(raw || "[]")) }
  catch (e) { return false }
  if (!(clients instanceof Array)) return false
  var i, c, cls, initial, title, size, w
  for (i = 0; i < clients.length; i++) {
    c = clients[i] || {}
    cls = String(c.class || "")
    initial = String(c.initialClass || "")
    title = String(c.title || "")
    if (cls !== "org.omarchy.quake" && initial !== "org.omarchy.quake" && cls !== "vkquake" && initial !== "vkquake" && title !== "Quake")
      continue
    size = c.size || [0, 0]
    w = (size && size[0]) ? Number(size[0]) : 0
    if (c.mapped === false || c.hidden) continue
    if (w >= 320) return true
  }
  return false
}

function filterMaps(maps, query, limit) {
  var list = maps instanceof Array ? maps : []
  var q = String(query || "").toLowerCase()
  var out = []
  var max = limit > 0 ? limit : 12
  var i, name
  for (i = 0; i < list.length; i++) {
    name = String(list[i])
    if (q && name.toLowerCase().indexOf(q) === -1) continue
    out.push(name)
    if (out.length >= max) break
  }
  return out
}

function matchClients(match) {
  if (!match || !match.clients) return []
  return match.clients instanceof Array ? match.clients : []
}

function matchLine(match, fallbackMap) {
  var map = (match && match.map) ? String(match.map) : String(fallbackMap || "")
  var n = match && match.players !== undefined ? Number(match.players) : 0
  var max = match && match.max ? Number(match.max) : 8
  if (!map) return n + " / " + max
  return map + "  ·  " + n + " / " + max
}
