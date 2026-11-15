# PeekCam

A tiny menu bar mirror for macOS: check how you look on camera before a call. Click the icon or press **⌃⇧M** and a
live preview drops down from the menu bar. The camera is on only while the preview is open.

Inspired by Hand Mirror; built to stay light (about 10 MB idle, about 50 MB with the preview open).

## Features

- Preview from the menu bar, or detached as a small floating window that stays in front
- **Snap** (Space): saves a PNG to `~/Pictures/PeekCam` and copies it to the clipboard
- Choose the camera, the size (S / M / L, 16:9 or 4:3) and mirroring
- **Lighting**: a bright frame around the picture, so the screen lights your face
- **Mic Check**: a level meter for the microphone (only the level is computed; nothing is recorded)
- Launch at login
- Works on its own or as a module inside [KTools](https://github.com/nivleking/kelvintools)

## Requirements

- macOS 14 or later
- Xcode Command Line Tools (`xcode-select --install`); full Xcode is not needed

## Build and install

```sh
git clone https://github.com/nivleking/peekcam.git && cd peekcam
swift test                      # logic tests
scripts/make-app.sh --install   # builds PeekCam.app and copies it to ~/Applications
```

`make-app.sh` signs the app with a local identity named "SnapMark Dev" when it exists, so the camera permission
survives rebuilds. Create it once with `scripts/make-cert.sh` from the
[SnapMark](https://github.com/nivleking/snapmark) repository, or set `PEEKCAM_SIGN` to your own identity. Without one
the app is ad-hoc signed and macOS asks for the permission again after each build.

## Use

| Action | How |
|---|---|
| Show or hide the preview | click the menu bar icon, or ⌃⇧M |
| Menu (camera, size, mirror, lighting, mic check) | right-click the icon |
| Snap a photo | Space, or the camera button on the preview |
| Detach / back to the menu bar | the button next to it |
| Close | Esc |

Settings live in `~/Library/Application Support/PeekCam/settings.json` (hot key, save folder, and the choices above).

## Permissions

| Permission | Why | Asked |
|---|---|---|
| Camera | the preview | the first time it opens |
| Microphone | Mic Check only | when you switch Mic Check on |

## Using it from another app

`PeekCamKit` exposes `PeekCamService` (`start`, `stop`, `togglePreview(from:)`, `fillMenu`, `updateHotKey`), which is
how KTools hosts it. `PeekCamCore` holds the pure logic and its tests. Design notes (in Indonesian): [DESAIN.md](DESAIN.md).

## License

[MIT](LICENSE)
