#!/bin/bash
# Launches KontaktApp: starts the local Flask server, then opens it
# in a chromeless browser window so it looks and feels like a native app.
set -e

APP_DIR="$(dirname "$(readlink -f "$0")")"
PORT=5157
URL="http://127.0.0.1:${PORT}/"

cd "$APP_DIR"

# Start the server in the background if it isn't already running
if ! curl -s "$URL" >/dev/null 2>&1; then
  python3 app.py >/tmp/kontaktapp.log 2>&1 &
  # wait for it to come up
  for i in $(seq 1 20); do
    sleep 0.3
    curl -s "$URL" >/dev/null 2>&1 && break
  done
fi

# Open in app mode - Firefox first, fall back to Chromium
if command -v firefox-esr >/dev/null 2>&1; then
  firefox-esr --new-window "$URL"
elif command -v firefox >/dev/null 2>&1; then
  firefox --new-window "$URL"
elif command -v chromium >/dev/null 2>&1; then
  chromium --app="$URL"
else
  xdg-open "$URL"
fi
