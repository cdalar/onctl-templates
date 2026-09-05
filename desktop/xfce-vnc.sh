#!/bin/bash
# Installs a lightweight XFCE desktop plus a TigerVNC server, so the VM can
# be reached graphically (not just over SSH) -- see boxctl-vms's
# docs/plans/gui-desktop-vnc-access.md for the browser-side plan this feeds
# into.
#
# Usage:
#   onctl up -n desktop -a desktop/xfce-vnc.sh
#   onctl up -n desktop -a desktop/xfce-vnc.sh -e VNC_PASSWORD=hunter2
#
# VNC_DISPLAY (default 1) selects the display/port: display :N listens on
# port 590N, so the default exposes 5901.
#
# VNC_PASSWORD is optional. Unset (the default) configures the VNC server
# with no password of its own -- SecurityTypes None -- because the server
# binds to localhost only (see -localhost below), so the only way to reach
# it at all is a local port-forward (SSH -L, or boxctl-vms's ticket-gated
# tunnel once that lands); that already-authenticated channel is the real
# access control here, not a second password prompt in the VNC client. Set
# VNC_PASSWORD if you want defense in depth, or if you're testing this
# script standalone without a tunnel in front of it yet.
set -ex
export DEBIAN_FRONTEND=noninteractive

VNC_DISPLAY="${VNC_DISPLAY:-1}"
VNC_USER=root
VNC_HOME=/root

apt-get update
apt-get install -y xfce4 xfce4-terminal dbus-x11 tigervnc-standalone-server

mkdir -p "${VNC_HOME}/.vnc"
cat <<'EOF' > "${VNC_HOME}/.vnc/xstartup"
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
EOF
chmod +x "${VNC_HOME}/.vnc/xstartup"

if [ -n "${VNC_PASSWORD:-}" ]; then
  echo "${VNC_PASSWORD}" | vncpasswd -f > "${VNC_HOME}/.vnc/passwd"
  chmod 600 "${VNC_HOME}/.vnc/passwd"
  VNC_SECURITY_ARGS="-rfbauth ${VNC_HOME}/.vnc/passwd"
else
  VNC_SECURITY_ARGS="-SecurityTypes None"
fi

# Type=simple + -fg (not Type=forking + PIDFile): TigerVNC's own
# double-fork-and-write-a-pidfile path is unreliable under systemd here --
# tested and reproduced live: systemd reported "Can't open PID file
# .../qwe:1.pid (yet?): Operation not permitted" and killed/flapped the
# unit even though the VNC server itself had started fine. -fg keeps
# vncserver in the foreground so systemd supervises the real process
# directly, no PID file involved.
cat <<EOF > "/etc/systemd/system/vncserver@.service"
[Unit]
Description=TigerVNC server on display %i
After=network.target

[Service]
Type=simple
User=${VNC_USER}
WorkingDirectory=${VNC_HOME}
ExecStart=/usr/bin/vncserver -fg -localhost yes ${VNC_SECURITY_ARGS} :%i
ExecStop=/usr/bin/vncserver -kill :%i
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now "vncserver@${VNC_DISPLAY}.service"

echo "VNC server listening on 127.0.0.1:$((5900 + VNC_DISPLAY)) (display :${VNC_DISPLAY})"
echo "Test from your machine with: ssh -L 590${VNC_DISPLAY}:localhost:590${VNC_DISPLAY} root@<vm-ip>"
echo "then point a VNC client at localhost:590${VNC_DISPLAY}"
