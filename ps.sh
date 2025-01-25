#!/bin/bash
(set -x; pgrep -U user -fal '/opt/kasmbins|kasm_(audio|upload|gamepad|printer|webcam)|Xvnc|dbus-daemon|ffmpeg|nginx' )