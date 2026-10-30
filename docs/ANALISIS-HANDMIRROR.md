# Analisis Hand Mirror 4.0.5 (read-only)

Tanggal: 2026-10-24. Sumber: `/Applications/Hand Mirror.app` di Mac Kelvin, dibaca dengan rea MCP
(`open_binary`, `inspect_plist`, `inspect_macho`) plus `otool`, `codesign`, `strings`, `footprint`.
Hanya perilaku yang dicatat. Tidak ada kode, gambar, video, atau font yang disalin.

## Identitas

| Hal | Nilai |
|---|---|
| Bundle id | `net.rafaelconde.Hand-Mirror` (Mac App Store, ada `_MASReceipt`) |
| Versi | 4.0.5 (build 1732), min macOS 14.4, dibuild Xcode 26.5 |
| Binary | Universal (x86_64 + arm64), Swift + SwiftUI, satu proses |
| Ukuran bundle | 27 MB, sebagian besar 15 video demo `.mp4` (onboarding, "Meet the developer") |
| Library pihak ketiga | `KeyboardShortcuts` (sindresorhus) untuk shortcut global |
| Entitlement | App Sandbox, camera, audio-input, photos-library, user-selected files, disable-library-validation |
| Izin (Info.plist) | Camera, Microphone (meter audio), Photo Library (simpan Snap) |

Framework yang di-link: AVFoundation, AVKit, CoreImage, CoreMedia, Photos, StoreKit, SwiftUI,
TipKit, ServiceManagement (launch at login), Carbon (hotkey), Combine.

## Fitur yang terlihat (dari string UI dan preferensi)

1. **Ikon menu bar → popover** berisi preview kamera live (dimirror). Opsi "Close popover when:
   Clicking outside / Clicking the icon again".
2. **Pilih kamera dan mikrofon** ("Available Cameras", "Saving default camera"). Kamera default disimpan.
3. **Mirror bisa dimatikan** ("For people who don't want the mirror").
4. **Ukuran** (`SizePicker`, "Hand Mirror Plus Small", `zoomLevel`) dan **Smart Window**: preview
   dilepas jadi jendela, "Keep window in front", "Close window when unfocused", "Lock aspect ratio".
5. **Snaps**: foto dari preview (tombol Snap atau Spasi), simpan ke folder pilihan atau Photo Library
   (album "Hand Mirror"), "Save automatically", "Include frame in picture", tanggal tulisan tangan
   (font `HandWritingFont.ttf`). Versi gratis dibatasi, "Hand Mirror Plus" (IAP) membuka tanpa batas.
6. **Mic Check**: meter level audio (`AudioMeterView`, `AVCaptureAudioDataOutput`).
7. **Lighting overlay** (`LightingOverlay`): layar terang di sekitar preview sebagai lampu wajah.
8. **Reactions**: memicu efek Reactions bawaan macOS (`AVCaptureReactionType`).
9. **Notch Trigger**: klik area di belakang kamera (notch) untuk membuka preview, plus deteksi ikon
   tertutup notch ("Menu bar icon is hidden by the notch - showing alert").
10. **Keyboard shortcut global**, "Show icon in the Dock", "Hide menu bar icon", launch at login,
    "Show only on hover", ikon alternatif.
11. Onboarding dengan video, TipKit, review prompt, tip jar.

Preferensi nyata Kelvin (`~/Library/Containers/.../Preferences`): `zoomLevel = 1`,
`isSnapsPreferenceOn = 1`, `showReactionEffectsButtons = 0`, `preferredDisplay`, belum beli Plus.

## Memori (diukur 2026-10-24 16:04Z, preview tertutup)

| Ukuran | Nilai |
|---|---|
| RSS | 158 MB |
| phys_footprint | **65 MB** |
| phys_footprint_peak | **207 MB** (saat preview/snap aktif) |

Dugaan sumber beban: SwiftUI + TipKit + StoreKit dimuat terus, AVKit `PlayerView` untuk video demo,
frame kamera diproses lewat CoreImage/`ImageRenderer` (snapshot SwiftUI) bukan langsung dari layer
preview, dan sesi kamera/audio kemungkinan tidak sepenuhnya dilepas setelah popover ditutup.

## Pelajaran untuk clone

- Preview cukup `AVCaptureVideoPreviewLayer` (GPU, frame tidak masuk heap aplikasi). Mirror lewat
  `connection.isVideoMirrored`.
- Sesi kamera hanya hidup selama preview terlihat, lalu dibongkar (bukan cuma `stopRunning`).
- Snap ambil satu frame lewat `AVCapturePhotoOutput` atau satu sample buffer, bukan render SwiftUI.
- Tanpa SwiftUI, TipKit, StoreKit, video, sandbox. Satu proses AppKit.
- Ghidra tidak dipakai: string dan simbol sudah cukup menjelaskan perilaku untuk MVP.
