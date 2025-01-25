#!/usr/bin/env bash
CUSER="${CUSTOM_USER:-user}"
kill -9 `pgrep -U $CUSER -f '/opt/kasmbins|kasm_(audio|upload|gamepad|printer|webcam)|Xvnc|dbus-daemon|ffmpeg|nginx'`