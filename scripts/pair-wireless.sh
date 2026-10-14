#!/usr/bin/env bash
# Enable wireless adb after a working USB connection, then optionally connect.
set -euo pipefail

PORT="${ADB_TCP_PORT:-5555}"

if ! command -v adb >/dev/null; then
  echo "adb not found. See README.md for install instructions." >&2
  exit 1
fi

adb start-server >/dev/null

USB_SERIAL=""
while read -r line; do
  [[ -z "$line" || "$line" == List* ]] && continue
  serial=$(awk '{print $1}' <<<"$line")
  state=$(awk '{print $2}' <<<"$line")
  [[ "$state" != "device" ]] && continue
  [[ "$serial" == *:* ]] && continue
  USB_SERIAL="$serial"
  break
done < <(adb devices)

if [[ -z "$USB_SERIAL" ]]; then
  echo "No USB adb device in 'device' state. Plug in, authorize, then retry." >&2
  adb devices -l >&2 || true
  exit 1
fi

echo "USB device: $USB_SERIAL"
echo "Switching to TCP/IP on port $PORT..."
adb -s "$USB_SERIAL" tcpip "$PORT"

# Prefer adb's reported WLAN IP; fall back to common interface names.
IP="$(adb -s "$USB_SERIAL" shell ip -f inet addr show wlan0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 || true)"
if [[ -z "$IP" ]]; then
  IP="$(adb -s "$USB_SERIAL" shell ip -f inet addr show wlan1 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 || true)"
fi
if [[ -z "$IP" ]]; then
  IP="$(adb -s "$USB_SERIAL" shell ip route 2>/dev/null | awk '/wlan|rmnet|ccmni/ {print $9; exit}' || true)"
fi

if [[ -z "$IP" ]]; then
  echo "Could not auto-detect phone Wi-Fi IP."
  echo "On the phone, note Settings → About → Status → IP address, then run:"
  echo "  adb connect <PHONE_IP>:$PORT"
  echo "Then: ./scripts/tft-scrcpy.sh --wireless"
  exit 0
fi

TARGET="${IP}:${PORT}"
echo "Connecting to $TARGET ..."
adb connect "$TARGET"
adb devices -l
echo
echo "You can unplug USB. Launch with:"
echo "  ./scripts/tft-scrcpy.sh --serial $TARGET"
echo "  # or: ./scripts/tft-scrcpy.sh --wireless"
