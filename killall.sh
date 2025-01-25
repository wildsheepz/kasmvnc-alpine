#!/usr/bin/env bash
kill -9 `pgrep -U user -f '/opt/kasmbins|kasm_(audio|upload|gamepad|printer|webcam)|Xvnc|dbus-daemon|ffmpeg|nginx'`