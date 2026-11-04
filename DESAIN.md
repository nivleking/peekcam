# PeekCam (clone Hand Mirror), DESAIN

Status: **Tahap 1 langkah 1–5 dikodekan (2026-10-30)**, nama PeekCam dan hotkey ⌃⇧M dipakai sesuai usulan. Tes 17/17 lulus, app terbangun dan terpasang di ~/Applications (2026-11-03). RAM idle terukur **9,5 MB** (target <12 MB). Preview kamera tampil dengan benar (2026-11-03). RAM saat preview terbuka **±50 MB** (target <40 MB, belum tercapai; puncak ±150-165 MB sesaat saat kamera start). Setelah preview ditutup **±35 MB** (dari 56 MB sebelum `malloc_zone_pressure_relief` ditambahkan di `CameraSession.stop`); sisanya ±50 ribu objek kecil milik framework AVFoundation/CoreMedia, sebagian besar sudah terkompres. Tidak bisa turun ke 9,5 MB (itu angka sebelum kamera pernah dibuka). Snap (Tahap 2) diuji 2026-11-03: PNG 1920x1080 tersimpan di ~/Pictures/PeekCam, dan tempel (⌘V) hasil snap dari clipboard berhasil. Jendela lepas (detach) diuji 2026-11-03: tampil sebagai jendela mengambang di depan app lain dan snap dari jendela itu bekerja. Rasio tetap dan posisi diingat belum diverifikasi.
Folder: `~/Documents/dev-lab/apps/rea-work/peekcam`. Nama sementara "PeekCam" (bisa diganti).
Analisis aslinya: `docs/ANALISIS-HANDMIRROR.md`.

## Tujuan

Klik ikon di menu bar (atau tekan hotkey), langsung lihat wajah sendiri dari kamera sebelum meeting.
Ringan: target **< 12 MB idle** dan **< 40 MB saat preview terbuka** (asli: 65 MB idle, puncak 207 MB).
UI berbahasa Inggris. Bisa berdiri sendiri dan juga jadi modul KTools.

## Arsitektur (sama seperti SnapMark)

```
Package.swift  (swift-tools 5.9, macOS 14, Swift Testing)
Sources/
  PeekCamCore/   logika murni tanpa AppKit/AVFoundation: Settings (JSON), SizePreset & geometri
                 aspect ratio, pemilihan kamera (fallback kalau kamera hilang), FileNamer snap,
                 AudioLevel (dBFS -> 0..1)
  PeekCamKit/    AppKit + AVFoundation: CameraSession (protocol, bisa dipalsukan di test),
                 PreviewView (AVCaptureVideoPreviewLayer), PreviewPopover, DetachedWindow,
                 HotKey (Carbon), Snapper, `public final class PeekCamService` (@MainActor)
  PeekCam/       app tipis: status item + PeekCamService
Tests/PeekCamCoreTests/
scripts/make-app.sh (pakai cert "SnapMark Dev"), make-icon.swift
```

`PeekCamService` (API untuk KTools): `start()`, `stop()`, `togglePreview(from: NSStatusBarButton?)`,
`isPreviewVisible`, `menuItems` (pilih kamera, mirror, ukuran). Tanpa tombol, panel muncul di bawah
menu bar dekat kursor. Saya tidak menyentuh `kelvintools/`; setelah siap saya kabari thread KTools.

## Cara hemat RAM

- Preview = `AVCaptureVideoPreviewLayer`; frame dirender GPU, tidak disalin ke memori aplikasi.
- `AVCaptureSession` dibuat saat popover dibuka dan dibongkar total saat ditutup (lampu kamera mati).
- Preset `.high` (720p) untuk preview; snap pakai `AVCapturePhotoOutput` hanya saat diminta.
- Tidak ada SwiftUI, video, StoreKit, sandbox, atau helper process.

## Tahapan (TDD, commit per langkah kecil)

**Tahap 1, MVP**
1. Skeleton package + Core: Settings, SizePreset (S/M/L, 16:9 dan 4:3), CameraPicker. Test dulu.
2. CameraSession + PreviewView, mirror on/off.
3. Status item + popover (tutup saat klik di luar atau klik ikon lagi), menu klik kanan:
   pilih kamera, Mirror, Size, Quit.
4. Hotkey global **⌃⇧M** untuk buka/tutup (bisa diubah di settings.json).
5. make-app.sh, signing "SnapMark Dev", install ke ~/Applications, ukur RAM.

**Tahap 2, Snap dan jendela**
6. Snap (Spasi atau tombol): simpan PNG ke `~/Pictures/PeekCam`, salin ke clipboard, kilat putih.
7. Detach jadi jendela floating: keep in front, lock aspect ratio, ingat posisi.

**Tahap 3, tambahan (opsional, Kelvin pilih)**
8. Mic Check: meter level mikrofon (butuh izin mic).
9. Lighting: bingkai putih terang di sekeliling preview untuk lampu wajah.
10. Launch at login (SMAppService), PeekCamKit siap untuk KTools.

**Tidak ikut diclone:** pembelian Plus, onboarding video, TipKit, review prompt, tanggal tulisan
tangan, simpan ke Photos, Reactions macOS, Notch Trigger (bisa ditambah nanti kalau mau).

## Izin

Kamera butuh `NSCameraUsageDescription` di Info.plist. Karena ditandatangani "SnapMark Dev",
izin kamera tetap setelah rebuild. Kalau macOS tidak memunculkan dialog setelah rebuild pertama,
Kelvin jalankan sendiri: `tccutil reset Camera dev.kelvin.PeekCam`.

## Pertanyaan untuk Kelvin

1. Nama "PeekCam" oke? (alternatif: "FaceCheck", "Mirrorlet")
2. Hotkey ⌃⇧M oke?
3. Tahap 3 mana yang mau dibuat?

## Tahap 3 (dikodekan 2026-11-03, dicoba dan diterima Kelvin 2026-11-04)

- **Lighting** (menu): bingkai putih tebal 12% di sekeliling gambar (`LightingFrame`), `lighting` di settings.json.
- **Mic Check** (menu): meter 90 px di kiri bawah preview, `AVCaptureAudioDataOutput` hanya saat dinyalakan, hanya level yang dihitung (`AudioLevel`, dBFS -80...0), tidak ada audio yang disimpan. Minta izin mikrofon sekali. `micCheck` di settings.json.
- **Launch at Login** (menu): `SMAppService.mainApp`.
- Tes: 26 lulus (AudioLevel, LightingFrame, settings baru).

## Integrasi ClipText

Hapus item *files* di popup ClipText (⌥⌫), atau Clear History (⌘⌥⌫) juga memindahkan file snap ke **Trash** (bisa dikembalikan), hanya bila file ada di folder `trashLinkedFilesIn` (default `~/Pictures/PeekCam`, di settings.json ClipText; kosongkan untuk mematikan). Batas otomatis (jumlah item, umur) tidak menyentuh file.
