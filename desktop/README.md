# XFCE desktop + VNC

Installs a lightweight XFCE desktop and a TigerVNC server, so a VM can be
reached graphically instead of only over SSH. XFCE is used rather than a
heavier desktop (e.g. GNOME) because it performs noticeably better over
plain VNC on a small VM.

## run vm + install desktop

```
onctl up -n desktop -a desktop/xfce-vnc.sh
```

By default the server listens on `127.0.0.1:5901` (display `:1`) on the
VM itself -- `-localhost yes` means it's not reachable from outside the
VM at all except through a forwarded/tunneled connection, so no VNC
password is set by default (`-SecurityTypes None`); the tunnel itself is
the access control.

To test this script directly (before any tunnel exists in front of it),
forward the port over SSH and point a VNC client at the local end:

```
ssh -L 5901:localhost:5901 root@<vm-ip>
# then, in a VNC client:
vncviewer localhost:5901
```

## optional variables

```
onctl up -n desktop -a desktop/xfce-vnc.sh -e VNC_PASSWORD=hunter2 -e VNC_DISPLAY=2
```

- `VNC_PASSWORD` -- if set, the server requires this password instead of
  running with no auth of its own. Useful for standalone testing without
  a tunnel in front of it yet.
- `VNC_DISPLAY` -- display number (default `1`); the listening port is
  always `5900 + VNC_DISPLAY`.
