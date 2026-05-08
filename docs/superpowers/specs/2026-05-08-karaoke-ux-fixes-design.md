# Design: Karaoke UX Fixes — Scroll Position, Animation, Track Change Bug

**Date:** 2026-05-08  
**Status:** Approved

## Problem Summary

Tiga masalah UX di `KaraokeView` dan `StatusBarController`:

1. **Posisi awal lirik di tengah** — Sebelum lagu mulai, lirik muncul di tengah layar karena `vertPad` diterapkan ke atas dan bawah. Harusnya mulai dari atas.
2. **Scroll patah saat pindah baris** — `spring(response: 0.35, dampingFraction: 0.9)` terlalu cepat dan stiff. Terasa snap/teleport bukan smooth.
3. **Lirik lama masih tampil saat ganti lagu** — `handleTrackChange` tidak membersihkan `lyricsState.lines` sebelum fetch baru. Selama 1–3 detik network request, judul baru sudah muncul tapi lirik masih lagu sebelumnya.

---

## Fix 1: Posisi Awal Lirik

**File:** `Hum/Views/KaraokeView.swift`

**Root cause:** `.padding(.vertical, vertPad)` menambahkan padding identik ke top dan bottom. Top padding sebesar setengah tinggi view membuat lirik pertama muncul di tengah meski belum ada active line.

**Fix:** Pisahkan padding — top `0`, bottom tetap `vertPad`:

```swift
// Sebelum:
.padding(.vertical, vertPad)

// Sesudah:
.padding(.top, 0)
.padding(.bottom, vertPad)
```

**Perilaku yang diharapkan:**
- Sebelum lagu mulai (`active == nil`): lirik pertama di atas
- Saat lagu jalan: active line di-scroll ke center secara natural
- Baris awal (index 0–N): muncul dekat atas (tidak ada konten di atasnya untuk centering)
- Baris tengah–akhir: ter-center karena ada konten di atas yang mengisi ruang

Bottom padding dipertahankan agar baris-baris terakhir tetap bisa di-scroll ke center.

---

## Fix 2: Animasi Scroll Lebih Smooth

**File:** `Hum/Views/KaraokeView.swift`

**Root cause:** Parameter spring terlalu agresif — `response: 0.35` (cepat) dan `dampingFraction: 0.9` (stiff, hampir tanpa bounce). Kombinasi ini menciptakan gerakan snap.

**Fix:** Ganti ke `interpolatingSpring(stiffness: 70, damping: 12)` — lebih organik, ada sedikit natural overshoot.

Dua tempat yang diubah:

```swift
// 1. Implicit animation pada VStack (untuk perubahan non-scroll)
.animation(.interpolatingSpring(stiffness: 70, damping: 12), value: active)

// 2. Explicit animation pada scrollTo
withAnimation(.interpolatingSpring(stiffness: 70, damping: 12)) {
    proxy.scrollTo(newActive, anchor: .center)
}
```

**Parameter rationale:**
- `stiffness: 70` — spring force yang cukup kuat tapi tidak snappy
- `damping: 12` — sedikit underdamped → natural overshoot kecil → terasa "hidup"
- Durasi efektif ~0.4–0.5 detik pada typical displacement (1–2 baris)

---

## Fix 3: Clear Lyrics Saat Track Change

**File:** `Hum/StatusBar/StatusBarController.swift`

**Root cause:** `handleTrackChange` tidak membersihkan `lyricsState.lines` sebelum memulai fetch baru. Selama network request berlangsung (~1–3 detik), UI menampilkan metadata lagu baru (title, artist, artwork) tapi lirik masih dari lagu sebelumnya.

**Fix:** Tambah `lyricsState.lines = []` segera setelah guard:

```swift
private func handleTrackChange(_ track: Track?) async {
    guard let track else {
        lyricsState.lines = []
        lyricsState.noLyricsFound = false
        return
    }
    lyricsState.lines = []          // ← tambahkan ini
    lyricsState.noLyricsFound = false
    if autoShowOnNewTrack {
        lyricsState.isManuallyHidden = false
    }
    let lines = await lyricsEngine.fetch(for: track)
    guard !Task.isCancelled else { return }
    lyricsState.lines = lines
    lyricsState.noLyricsFound = lines.isEmpty
}
```

**Perilaku yang diharapkan:**
- Saat track berganti: lirik langsung kosong (sync dengan update title/artist)
- Selama fetch: area lirik kosong (tidak menampilkan lirik lama)
- Setelah fetch selesai: lirik baru muncul

---

## Files yang Berubah

| File | Perubahan |
|------|-----------|
| `Hum/Views/KaraokeView.swift` | Fix 1 (padding) + Fix 2 (spring parameter) |
| `Hum/StatusBar/StatusBarController.swift` | Fix 3 (clear lines) |

## Testing

- Manual: buka app, lihat posisi awal lirik sebelum play → harus di atas
- Manual: play lagu, perhatikan scroll saat baris berganti → harus smooth dengan sedikit overshoot
- Manual: skip ke lagu berikutnya → lirik harus langsung kosong bersamaan dengan update title/artist
- Unit: tidak ada perubahan yang memerlukan test baru (behavior changes are visual/timing)
