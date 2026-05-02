import SwiftUI

struct HumWindowView: View {
    @ObservedObject var lyricsState: LyricsState
    @ObservedObject var musicObserver: MusicObserver

    private var activeLineIndex: Int? {
        activeIndex(
            in: lyricsState.lines,
            at: musicObserver.playbackPosition + lyricsState.syncOffset
        )
    }

    var body: some View {
        ZStack {
            VibrancyView()
            VStack(spacing: 0) {
                HStack(alignment: .top) {
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
                .frame(height: 52)

                if !lyricsState.lines.isEmpty {
                    KaraokeView(
                        lines: lyricsState.lines,
                        active: activeLineIndex,
                        fontSize: lyricsState.fontSize
                    )
                    .equatable()
                } else if lyricsState.noLyricsFound {
                    VStack {
                        Spacer()
                        Text("Oops, we don't have lyrics for this one")
                            .font(.callout)
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
