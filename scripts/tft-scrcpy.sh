#!/usr/bin/env bash
# Low-latency scrcpy launcher tuned for Team Fight Tactics (click/drag).
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: tft-scrcpy.sh [options]

Options:
  --audio          Forward phone audio (off by default for lower latency)
  --screen-off     Turn the phone screen off while mirroring
  --h264           Force H.264 instead of H.265
  --wireless       Prefer a TCP/IP adb device if one is connected
  --serial SERIAL  Use a specific adb serial (USB or IP:port)
  -h, --help       Show this help

Environment:
  ADB_SERIAL       Same as --serial
  TFT_SCRCPY_EXTRA Extra args appended to scrcpy (quoted string split by words)
EOF
}

AUDIO=0
SCREEN_OFF=0
CODEC=h265
PREFER_WIRELESS=0
SERIAL="${ADB_SERIAL:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --audio) AUDIO=1; shift ;;
    --screen-off) SCREEN_OFF=1; shift ;;
    --h264) CODEC=h264; shift ;;
    --wireless) PREFER_WIRELESS=1; shift ;;
    --serial) SERIAL="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! command -v adb >/dev/null || ! command -v scrcpy >/dev/null; then
  echo "Need adb and scrcpy on PATH. See README.md for install instructions." >&2
  exit 1
fi

adb start-server >/dev/null

pick_serial() {
  local line serial state
  local -a usb_devs=() tcp_devs=()

  while read -r line; do
    [[ -z "$line" || "$line" == List* ]] && continue
    serial=$(awk '{print $1}' <<<"$line")
    state=$(awk '{print $2}' <<<"$line")
    [[ "$state" != "device" ]] && continue
    if [[ "$serial" == *:* ]]; then
      tcp_devs+=("$serial")
    else
      usb_devs+=("$serial")
    fi
  done < <(adb devices)

  if [[ -n "$SERIAL" ]]; then
    printf '%s\n' "$SERIAL"
    return
  fi

  if [[ "$PREFER_WIRELESS" -eq 1 && ${#tcp_devs[@]} -gt 0 ]]; then
    printf '%s\n' "${tcp_devs[0]}"
    return
  fi
  if [[ ${#usb_devs[@]} -gt 0 ]]; then
    printf '%s\n' "${usb_devs[0]}"
    return
  fi
  if [[ ${#tcp_devs[@]} -gt 0 ]]; then
    printf '%s\n' "${tcp_devs[0]}"
    return
  fi
  return 1
}

if ! SERIAL=$(pick_serial); then
  echo "No authorized adb device found." >&2
  echo "On the phone: enable USB debugging, set USB mode to File transfer," >&2
  echo "accept the RSA prompt, then re-run. See README.md." >&2
  adb devices -l >&2 || true
  exit 1
fi

echo "Using device: $SERIAL"

ARGS=(
  --serial="$SERIAL"
  --video-codec="$CODEC"
  --max-size=1920
  --max-fps=60
  --window-title=TFT
  --stay-awake
  --keyboard=uhid
)

if [[ "$AUDIO" -eq 0 ]]; then
  ARGS+=(--no-audio)
fi
if [[ "$SCREEN_OFF" -eq 1 ]]; then
  ARGS+=(--turn-screen-off)
fi

# shellcheck disable=SC2206
EXTRA=( ${TFT_SCRCPY_EXTRA:-} )

set +e
scrcpy "${ARGS[@]}" "${EXTRA[@]}"
status=$?
set -e

# H.265 sometimes unsupported; retry once with H.264
if [[ $status -ne 0 && "$CODEC" == "h265" ]]; then
  echo "scrcpy failed with H.265 (exit $status); retrying with H.264..." >&2
  ARGS=(
    --serial="$SERIAL"
    --video-codec=h264
    --max-size=1920
    --max-fps=60
    --window-title=TFT
    --stay-awake
    --keyboard=uhid
  )
  [[ "$AUDIO" -eq 0 ]] && ARGS+=(--no-audio)
  [[ "$SCREEN_OFF" -eq 1 ]] && ARGS+=(--turn-screen-off)
  scrcpy "${ARGS[@]}" "${EXTRA[@]}"
  status=$?
fi

exit "$status"
