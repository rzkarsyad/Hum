import SwiftUI

struct HumWindowView: View {
    @ObservedObject var lyricsState: LyricsState
    @ObservedObject var musicObserver: MusicObserver

    var body: some View {
        // Computed once per body pass (body re-runs at 60fps via musicObserver):
        // buildItems is deterministic in lyricsState.lines, so the resulting array
        // compares equal across ticks and KaraokeView's .equatable() gate skips it.
        let items = buildItems(from: lyricsState.lines)
        let activeItem = activeItemIndex(in: items, at: musicObserver.playbackPosition)
        ZStack {
            VibrancyView()
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 10) {
                    artworkView
                    VStack(alignment: .leading, spacing: 2) {
                        Text(musicObserver.currentTrack?.title ?? "")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text(musicObserver.currentTrack?.artist ?? "")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Spacer()
                    Button {
                        lyricsState.isMinimized.toggle()
                    } label: {
                        Image(systemName: lyricsState.isMinimized ? "chevron.down.circle" : "chevron.up.circle")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)

                    Button {
                        lyricsState.isManuallyHidden = true
                    } label: {
                        Image(systemName: "eye.slash")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(height: 60)

                if !lyricsState.lines.isEmpty {
                    KaraokeView(
                        items: items,
                        active: activeItem,
                        fontSize: lyricsState.fontSize,
                        musicObserver: musicObserver
                    )
                    .equatable()
                } else if lyricsState.networkError {
                    emptyState(icon: "wifi.slash", message: "Can't reach lyrics server.\nCheck your internet connection.")
                } else if lyricsState.noLyricsFound {
                    emptyState(icon: "music.note.slash", message: "No lyrics found for this track.")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.white.opacity(0.3))
            Text(message)
                .font(.callout)
                .foregroundColor(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Spacer()
        }
    }

    @ViewBuilder
    private var artworkView: some View {
        Group {
            if let artwork = musicObserver.currentArtwork {
                Image(nsImage: artwork)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                    .id(musicObserver.currentTrack?.title ?? "")
            } else {
                Image(systemName: "music.note")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.system(size: 16))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.1))
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .animation(.easeInOut(duration: 0.3), value: musicObserver.currentTrack?.title)
    }
}
