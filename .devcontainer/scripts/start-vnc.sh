#!/usr/bin/env bash
# Starts the VNC X server (and noVNC, when the port is free) for this devcontainer.
#
# Display and ports come from the container environment so a second container on
# a host-network setup can use a different pair:  DISPLAY=:5 GZ_NOVNC_PORT=6081
set -u

DISPLAY_NUM="${DISPLAY:-:1}"
DISPLAY_NUM="${DISPLAY_NUM#:}"
DISPLAY_NUM="${DISPLAY_NUM%%.*}"
GEOMETRY="${GZ_VNC_GEOMETRY:-1920x1080}"
NOVNC_PORT="${GZ_NOVNC_PORT:-6080}"
VNC_PORT=$((5900 + DISPLAY_NUM))
HOME_DIR="${HOME:-/root}"
SOCKET="/tmp/.X11-unix/X${DISPLAY_NUM}"

log() { printf '[start-vnc] %s\n' "$*"; }

# --- clear stale state from a previous run -----------------------------------
tigervncserver -kill ":${DISPLAY_NUM}" >/dev/null 2>&1 || true
rm -f "/tmp/.X${DISPLAY_NUM}-lock" "${SOCKET}"
rm -f "${HOME_DIR}/.vnc/"*":${DISPLAY_NUM}.pid" 2>/dev/null || true

# --- X server ----------------------------------------------------------------
log "starting Xvnc on :${DISPLAY_NUM} (${GEOMETRY})"
setsid tigervncserver ":${DISPLAY_NUM}" \
  -geometry "${GEOMETRY}" \
  -depth 24 \
  -localhost yes \
  -SecurityTypes None \
  >/tmp/start-vnc.log 2>&1

for _ in $(seq 1 20); do [ -S "${SOCKET}" ] && break; sleep 1; done
if [ ! -S "${SOCKET}" ]; then
  log "ERROR: Xvnc did not come up on :${DISPLAY_NUM}; see /tmp/start-vnc.log"
  exit 0
fi

# --- noVNC --------------------------------------------------------------------
port_in_use() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null && { exec 3>&- 3<&-; return 0; }; return 1; }

if ! command -v websockify >/dev/null 2>&1; then
  log "websockify missing; VNC only on :${DISPLAY_NUM} (no browser access)"
elif port_in_use "${NOVNC_PORT}"; then
  log "noVNC not started: port ${NOVNC_PORT} is already in use"
else
  log "starting noVNC on :${NOVNC_PORT} -> 127.0.0.1:${VNC_PORT}"
  setsid nohup websockify --web=/usr/share/novnc "${NOVNC_PORT}" "127.0.0.1:${VNC_PORT}" \
    >/tmp/novnc.log 2>&1 </dev/null &
  sleep 2
  port_in_use "${NOVNC_PORT}" || log "WARNING: noVNC failed to listen; see /tmp/novnc.log"
fi

log "VNC ready on :${DISPLAY_NUM} (http://localhost:${NOVNC_PORT}/vnc.html)"
