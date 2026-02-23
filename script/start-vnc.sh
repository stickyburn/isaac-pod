#!/bin/bash

# Cleanup any existing
pkill -f Xvfb 2>/dev/null || true
pkill -f fluxbox 2>/dev/null || true  
pkill -f x11vnc 2>/dev/null || true
pkill -f novnc 2>/dev/null || true

rm -rf /tmp/.X*-lock /tmp/.X11-unix/X* 2>/dev/null || true
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

export DISPLAY=:1
Xvfb :1 -screen 0 1920x1080x24 &
sleep 1
fluxbox &
sleep 1
x11vnc -display :1 -forever -shared -rfbport 5900 -localhost &
sleep 1
/usr/share/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 6901 &

echo "VNC ready: http://<your-ip>:6901/vnc.html"
