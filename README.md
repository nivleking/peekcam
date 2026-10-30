# PeekCam

Lihat wajah sendiri dari kamera sebelum meeting: klik ikon di menu bar atau tekan **⌃⇧M**.
Klik kanan ikon untuk pilih kamera, ukuran (S/M/L, 16:9 atau 4:3), dan Mirror.
Kamera hanya menyala selama preview terbuka. Desain: [DESAIN.md](DESAIN.md).

```bash
swift test                      # tes logika (Core)
scripts/make-app.sh --install   # build, tanda tangani "SnapMark Dev", pasang ke ~/Applications
```

Settings: `~/Library/Application Support/PeekCam/settings.json`.
Untuk KTools, pakai `PeekCamKit` → `PeekCamService` (`start`, `stop`, `togglePreview(from:)`, `fillMenu`).
