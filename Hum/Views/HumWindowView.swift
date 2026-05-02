import SwiftUI

struct HumWindowView: View {
    @ObservedObject var lyricsState: LyricsState
    @ObservedObject var musicObserver: MusicObserver

    var body: some View {
        ZStack {
            VibrancyView()
            if !lyricsState.lines.isEmpty {
                KaraokeView(
                    lines: lyricsState.lines,
                    musicObserver: musicObserver,
                    syncOffset: lyricsState.syncOffset
                )
            }
        }
        .frame(width: 320, height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
