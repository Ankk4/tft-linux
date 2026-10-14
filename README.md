# TFT on Linux (phone + scrcpy)

Play Team Fight Tactics from your Linux desktop by mirroring a real Android
phone with [scrcpy](https://github.com/Genymobile/scrcpy).

As of 2026, Riot's mobile anti-cheat (`libmvg`) makes TFT crash on Waydroid and
commercial emulators. The PC client needs desktop Vanguard (not viable on
Linux). A physical phone is the workable path.

## Dependencies

You need `scrcpy`, `adb` (android-tools / platform-tools), and udev rules for
Android devices:

| Distro | Command |
|--------|---------|
| Arch | `sudo pacman -S --needed scrcpy android-tools android-udev` |
| Debian / Ubuntu | `sudo apt install scrcpy adb android-sdk-platform-tools-common` |
| Fedora | `sudo dnf install scrcpy android-tools android-udev-rules` |

Then add yourself to the `adbusers` group (skip if your distro's udev rules
don't use it):

```bash
sudo usermod -aG adbusers "$USER"   # then log out/in once
```

## udev rule (only if needed)

Stock udev rules cover most devices. If `adb devices` stays empty with a
working cable and debugging enabled, find your phone's USB vendor ID:

```bash
lsusb
# e.g. Bus 001 Device 004: ID 339b:1234 Honor Device Co., Ltd.
```

Create `/etc/udev/rules.d/51-android.rules` (vendor ID from `lsusb`, lowercase):

```
SUBSYSTEM=="usb", ATTR{idVendor}=="339b", MODE="0660", GROUP="adbusers", TAG+="uaccess"
```

Then:

```bash
sudo udevadm control --reload-rules && sudo udevadm trigger
```

## Phone setup (one-time)

1. **Developer options**: Settings → About phone → tap *Build number* 7 times.
2. Enable **USB debugging**. Some vendors (Huawei/HONOR, Xiaomi, …) have extra
   ADB toggles like *USB debugging (Security settings)* or *Allow ADB debugging
   in charge only mode* — enable those too if present.
3. Plug in USB. Set USB mode to **File transfer / MTP** (not Charge only).
4. Accept the **Allow USB debugging?** RSA prompt on the phone.
5. Confirm:

```bash
adb devices
# expect: <serial>    device
```

If the list is empty, USB debugging is still off or the cable is charge-only.
If you see `unauthorized`, unlock the phone and accept the prompt.

Install **Teamfight Tactics** from the Play Store on the phone and sign in.

## Play

```bash
./scripts/tft-scrcpy.sh
```

Defaults: H.265 @ 60 fps, max dimension 1920, no audio forwarding (game audio
stays on the phone), stay-awake, UHID keyboard for chat. Mouse click/drag maps
to touch (what TFT needs).

Useful flags:

| Flag | Effect |
|------|--------|
| `--audio` | Forward phone audio to the PC |
| `--screen-off` | Blank the phone display while mirroring |
| `--h264` | Force H.264 if H.265 fails |
| `--wireless` | Prefer a TCP/IP adb device |
| `--serial SERIAL` | Pin a specific device |

## Wireless (optional)

With USB already authorized and phone on the same Wi-Fi:

```bash
./scripts/pair-wireless.sh
# unplug cable
./scripts/tft-scrcpy.sh --wireless
```

## Controls (scrcpy)

- Left click / drag: touch
- Right click: back
- Middle click: home
- `Alt`+`f`: fullscreen toggle
- Pinch: `Ctrl`+click-drag

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `adb devices` empty | Enable USB debugging; try another cable/port; File transfer mode |
| `unauthorized` | Unlock phone, accept RSA; or revoke USB debugging authorizations and replug |
| Permission denied on `/dev/bus/usb/...` | udev rule + `adbusers` group + re-login (see above) |
| Device invisible despite udev rule | Toggle USB debugging off/on; try another cable; enable extra ADB toggles if your vendor has them |
| Black / laggy video | Try `--h264`; lower size: `TFT_SCRCPY_EXTRA='--max-size=1280' ./scripts/tft-scrcpy.sh` |

## Why not Waydroid / Wine?

Documented for context only. Do not expect them to work for current TFT sets.
