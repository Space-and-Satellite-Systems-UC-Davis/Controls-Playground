#!/bin/bash
set -e

export DISPLAY=:1

echo "Cleaning up any existing VNC locks..."
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1

echo "Starting VNC server (no password)..."
tigervncserver :1 \
  -geometry 1920x1080 \
  -depth 24 \
  -localhost yes \
  -SecurityTypes None \
  --I-KNOW-THIS-IS-INSECURE &

# Wait for VNC to start
sleep 5

echo "Starting noVNC..."
websockify --web=/usr/share/novnc/ 6080 localhost:5901 &

echo "=========================================="
echo "VNC server ready!"
echo "Open: http://localhost:6080/vnc.html"
echo "No password required"
echo "=========================================="

# Keep script running
wait