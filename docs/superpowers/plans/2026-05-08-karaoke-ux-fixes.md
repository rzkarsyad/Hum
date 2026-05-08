# Karaoke UX Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Perbaiki tiga UX issues di karaoke view: posisi awal lirik di atas, scroll lebih smooth dengan interpolating spring, dan lirik langsung kosong saat ganti lagu.

**Architecture:** Dua file yang diubah secara independen. `KaraokeView.swift` menerima dua perubahan kecil (padding dan spring parameter). `StatusBarController.swift` menerima satu tambahan baris di `handleTrackChange`. Tidak ada perubahan arsitektur.

**Tech Stack:** Swift, SwiftUI (`interpolatingSpring`, `ScrollViewReader`), Combine

---

## File Map

| File | Perubahan |
|------|-----------|
| `Hum/Views/KaraokeView.swift` | Fix padding (top=0, bottom=vertPad) + ganti spring parameter di 2 tempat |
| `Hum/StatusBar/StatusBarController.swift` | Tambah `lyricsState.lines = []` sebelum fetch di `handleTrackChange` |

---

## Task 1: KaraokeView — Posisi Awal + Smooth Scroll

**Files:**
- Modify: `Hum/Views/KaraokeView.swift`

**Context:** Dua bug di file ini:
1. `.padding(.vertical, vertPad)` menambah top padding setengah tinggi view → lirik pertama muncul di tengah sebelum lagu mulai
2. `spring(response: 0.35, dampingFraction: 0.9)` terlalu cepat dan stiff → scroll terasa snap

Tidak ada unit test yang relevan untuk perubahan visual/animasi ini — verifikasi via build + manual.

- [ ] **Step 1: Baca file saat ini**

```bash
cat Hum/Views/KaraokeView.swift
```

Pastikan kamu melihat:
- `.padding(.vertical, vertPad)` di dalam `VStack` body
- `.animation(.spring(response: 0.35, dampingFraction: 0.9), value: active)` di akhir `VStack`
- `withAnimation(.spring(response: 0.35, dampingFraction: 0.9))` di dalam `onChange(of: active)`

- [ ] **Step 2: Ganti `.padding(.vertical, vertPad)` → padding asimetris**

Temukan baris ini:
```swift
.padding(.vertical, vertPad)
```

Ganti dengan:
```swift
.padding(.top, 0)
.padding(.bottom, vertPad)
```

- [ ] **Step 3: Ganti spring animation di VStack**

Temukan baris ini (di akhir `VStack`):
```swift
.animation(.spring(response: 0.35, dampingFraction: 0.9), value: active)
```

Ganti dengan:
```swift
.animation(.interpolatingSpring(stiffness: 70, damping: 12), value: active)
```

- [ ] **Step 4: Ganti spring animation di `onChange`**

Temukan baris ini (di dalam `onChange(of: active)`):
```swift
withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
    proxy.scrollTo(newActive, anchor: .center)
}
```

Ganti dengan:
```swift
withAnimation(.interpolatingSpring(stiffness: 70, damping: 12)) {
    proxy.scrollTo(newActive, anchor: .center)
}
```

- [ ] **Step 5: Build untuk pastikan compile**

```bash
xcodebuild build -scheme Hum 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Jalankan test suite**

```bash
xcodebuild test -scheme Hum 2>&1 | tail -5
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git add Hum/Views/KaraokeView.swift
git commit -m "fix: lyrics start at top, smooth interpolating spring scroll"
```

---

## Task 2: StatusBarController — Clear Lyrics Saat Track Change

**Files:**
- Modify: `Hum/StatusBar/StatusBarController.swift`

**Context:** `handleTrackChange` tidak membersihkan `lyricsState.lines` sebelum memulai fetch baru. Selama 1–3 detik request ke LRCLIB, title/artist/artwork sudah menampilkan lagu baru tapi lirik masih dari lagu lama.

- [ ] **Step 1: Baca method `handleTrackChange` saat ini**

```bash
grep -n "handleTrackChange" Hum/StatusBar/StatusBarController.swift
```

Lalu baca sekitar baris tersebut. Pastikan method-nya terlihat seperti ini:

```swift
private func handleTrackChange(_ track: Track?) async {
    guard let track else {
        lyricsState.lines = []
        lyricsState.noLyricsFound = false
        return
    }
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

- [ ] **Step 2: Tambah `lyricsState.lines = []` setelah guard**

Temukan baris ini:
```swift
    lyricsState.noLyricsFound = false
    if autoShowOnNewTrack {
```

Ganti dengan:
```swift
    lyricsState.lines = []
    lyricsState.noLyricsFound = false
    if autoShowOnNewTrack {
```

Hasil akhir method harus seperti ini:

```swift
private func handleTrackChange(_ track: Track?) async {
    guard let track else {
        lyricsState.lines = []
        lyricsState.noLyricsFound = false
        return
    }
    lyricsState.lines = []
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

- [ ] **Step 3: Build untuk pastikan compile**

```bash
xcodebuild build -scheme Hum 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Jalankan test suite**

```bash
xcodebuild test -scheme Hum 2>&1 | tail -5
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Hum/StatusBar/StatusBarController.swift
git commit -m "fix: clear lyrics immediately on track change"
```

---

## Checklist Manual Testing

Setelah kedua task selesai, verifikasi manual di Apple Music:

- [ ] Buka app tanpa musik → lirik pertama tampil di **atas**, bukan tengah
- [ ] Play lagu → saat baris berganti, scroll terasa **smooth** dengan sedikit natural overshoot
- [ ] Skip ke lagu berikutnya → lirik **langsung kosong** bersamaan dengan update title/artist
- [ ] Push ke GitHub: `git push origin main`
