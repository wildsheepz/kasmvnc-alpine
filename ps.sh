#!/bin/bash
CUSER="${CUSTOM_USER:-user}"
(set -x; pgrep -U $CUSER -fal '/opt/kasmbins|kasm_(audio|upload|gamepad|printer|webcam)|Xvnc|dbus-daemon|ffmpeg|nginx' )