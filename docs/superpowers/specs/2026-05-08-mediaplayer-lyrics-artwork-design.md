# Design: MediaPlayer Lyrics Sync & Artwork Display

**Date:** 2026-05-08  
**Status:** Approved

## Problem

Lyrics sync tidak konsisten — kadang pas, kadang terlambat, kadang terlalu cepat. Ada dua akar masalah:

1. **Position drift** — `MusicObserver` pakai AppleScript (IPC call setiap 500ms). Latency AppleScript menyebabkan anchor position tidak akurat, dan interpolasi 60fps tetap mewarisi error tersebut.
2. **Timestamp mismatch** — Lirik dari lrclib.net adalah crowd-sourced. Timestampnya mungkin tidak cocok persis dengan versi track yang diputar user.

Selain itu, belum ada tampilan cover image/artwork.

## Solution Overview

Ganti seluruh AppleScript stack dengan `MPMusicPlayerController.systemMusicPlayer` dari MediaPlayer framework. Ini memberikan:
- `currentPlaybackTime` langsung dari framework — tidak ada IPC overhead
- `nowPlayingItem` sebagai `MPMediaItem` — satu objek yang berisi track info, `.lyrics`, dan `.artwork`

Tambah `MPMediaItemLyricsSource` sebagai primary lyrics source, dan tampilkan artwork di header window.

## Architecture

### 1. `MusicObserver` — Ganti AppleScript → MPMusicPlayerController

**Perubahan:**
- Hapus `pollTimer`, `displayTimer`, `pollScript`, `compiledScript`, `runAppleScript`, `basePosition`, `baseDate`, dan semua logika interpolasi
- Gunakan `MPMusicPlayerController.systemMusicPlayer` (singleton)
- Subscribe ke dua `NotificationCenter` notification:
  - `MPMusicPlayerControllerNowPlayingItemDidChange` → update `currentTrack` dan `currentMediaItem`
  - `MPMusicPlayerControllerPlaybackStateDidChange` → update `isPlaying`
- Panggil `beginGeneratingPlaybackNotifications()` saat `start()`, `endGeneratingPlaybackNotifications()` saat `stop()`
- `playbackPosition` dibaca dari `systemMusicPlayer.currentPlaybackTime` — tetap di-drive oleh `displayTimer` 60fps untuk smooth UI, tapi nilainya langsung dari API bukan interpolasi

**Properties baru di `MusicObserver`:**
```swift
@Published private(set) var currentMediaItem: MPMediaItem? = nil
@Published private(set) var currentArtwork: NSImage? = nil
```

**Alur update:**
```
NowPlayingItemDidChange →
  currentMediaItem = systemMusicPlayer.nowPlayingItem
  currentTrack = Track(from: currentMediaItem)
  currentArtwork = currentMediaItem?.artwork?.image(at: CGSize(width: 40, height: 40))
```

**Authorization:** Panggil `MPMediaLibrary.requestAuthorization` saat `start()`. Jika denied, fallback ke currentTrack = nil dan log warning. App tidak crash.

### 2. `MPMediaItemLyricsSource` — Lyrics Source Baru

File baru: `Hum/LyricsEngine/MPMediaItemLyricsSource.swift`

```swift
struct MPMediaItemLyricsSource: LyricsSource {
    func fetchSyncedLyrics(for track: Track) async -> String? { nil }
    func fetchSyncedLyrics(from mediaItem: MPMediaItem) -> String? {
        guard let raw = mediaItem.lyrics, !raw.isEmpty else { return nil }
        return isLRC(raw) ? raw : nil
    }
}
```

Deteksi LRC: cek apakah string mengandung pattern `[mm:ss.xx]` di awal baris. Kalau iya → return as-is ke `LRCParser`. Kalau plain text → return `nil` → fallback ke LRCLIB.

### 3. `LyricsEngine` — Update fetch signature

Method `fetch(for:mediaItem:)` menerima parameter opsional `MPMediaItem?`:

```swift
func fetch(for track: Track, mediaItem: MPMediaItem? = nil) async -> [LyricLine]
```

Urutan prioritas:
1. `MPMediaItemLyricsSource` (jika `mediaItem` ada dan lyrics-nya LRC)
2. `LRCLIBSource` (sama seperti sekarang)

Cache key tetap `Track` (tidak berubah).

### 4. `StatusBarController` — Update fetch call

```swift
let lines = await lyricsEngine.fetch(for: track, mediaItem: musicObserver.currentMediaItem)
```

### 5. `HumWindowView` — Tambah Artwork Thumbnail

Header layout diubah dari:
```
[Title + Artist] ... [minimize] [hide]
```
Menjadi:
```
[Artwork 40×40] [Title + Artist] ... [minimize] [hide]
```

**Spesifikasi artwork:**
- `Image(nsImage: artwork)` atau placeholder `Image(systemName: "music.note")` jika nil
- Size: 40×40pt, `cornerRadius: 6`, `scaledToFill`
- Padding kiri: 12pt (sama dengan padding header yang ada)
- Animate ke/dari placeholder dengan `.animation(.easeInOut, value: musicObserver.currentArtwork != nil)`

## Data Flow

```
MPMusicPlayerController
  ├── nowPlayingItem (MPMediaItem)
  │     ├── .lyrics → MPMediaItemLyricsSource → LRCParser → [LyricLine]
  │     │                    (nil) → LRCLIBSource → LRCParser → [LyricLine]
  │     └── .artwork → NSImage → HumWindowView header
  ├── currentPlaybackTime → MusicObserver.playbackPosition → activeIndex()
  └── playbackState → MusicObserver.isPlaying
```

## Error Handling

| Skenario | Penanganan |
|----------|------------|
| User deny Music library access | `currentMediaItem = nil`, lyrics fallback ke LRCLIB, no artwork |
| `nowPlayingItem` nil (tidak ada yang diputar) | Sama seperti sekarang: `currentTrack = nil` |
| `MPMediaItem.lyrics` plain text | Return nil dari MPMediaItemLyricsSource, lanjut ke LRCLIB |
| `artwork?.image(at:)` return nil | Tampilkan placeholder icon `music.note` |
| MPMusicPlayerController tidak tersedia | Tidak mungkin di macOS 15+ (target minimum app) |

## Files yang Berubah

| File | Perubahan |
|------|-----------|
| `MusicObserver/MusicObserver.swift` | Ganti total: AppleScript → MPMusicPlayerController |
| `LyricsEngine/LyricsEngine.swift` | Update signature `fetch(for:mediaItem:)` |
| `LyricsEngine/MPMediaItemLyricsSource.swift` | **File baru** |
| `LyricsEngine/MusicKitSource.swift` | Tidak berubah (tetap stub) |
| `StatusBar/StatusBarController.swift` | Update panggilan `lyricsEngine.fetch` |
| `Views/HumWindowView.swift` | Tambah artwork thumbnail di header |
| `Hum/Info.plist` | Sudah ada `NSAppleMediaLibraryUsageDescription` — tidak perlu tambah |

## Testing

- `MusicObserverTests.swift` — Update/replace test AppleScript mock dengan MPMusicPlayerController mock
- `LyricsEngineTests.swift` — Tambah test untuk `MPMediaItemLyricsSource`: LRC detected, plain text → nil
- Manual: verifikasi artwork muncul di header, verifikasi lirik sync lebih akurat
