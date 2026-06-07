import SwiftUI
import Translation

/// Shared layout constants. The header height is the single source of truth for
/// both the SwiftUI header and the minimized window height (WindowManager) so the
/// collapsed bar matches the header exactly and never clips its content.
enum HumLayout {
    static let headerHeight: CGFloat = 60
}

struct HumWindowView: View {
    @ObservedObject var lyricsState: LyricsState
    @ObservedObject var musicObserver: MusicObserver

    /// Drives the on-device translation task. Non-nil only when translation is on
    /// and lyrics exist; invalidated to re-translate on track change.
    @State private var translationConfig: TranslationSession.Configuration?

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
                    controlButtons
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(height: HumLayout.headerHeight)

                if !lyricsState.lines.isEmpty {
                    KaraokeView(
                        items: items,
                        active: activeItem,
                        fontSize: lyricsState.fontSize,
                        translations: lyricsState.translations,
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
        .translationTask(translationConfig) { session in
            await runTranslation(session)
        }
        .onChange(of: lyricsState.showTranslation) { _, _ in refreshTranslationConfig() }
        .onChange(of: musicObserver.currentTrack?.title) { _, _ in refreshTranslationConfig() }
        .onChange(of: lyricsState.lines.count) { _, _ in refreshTranslationConfig() }
    }

    // MARK: - Translation

    /// Build/refresh/clear the translation configuration based on the toggle and
    /// whether there are lyrics. Invalidating an existing config re-runs the task
    /// for the new track's lines.
    private func refreshTranslationConfig() {
        guard lyricsState.showTranslation, !lyricsState.lines.isEmpty else {
            translationConfig = nil
            lyricsState.translations = [:]
            return
        }
        lyricsState.translations = [:]
        if translationConfig == nil {
            translationConfig = TranslationSession.Configuration(source: nil, target: Locale.current.language)
        } else {
            translationConfig?.invalidate()
        }
    }

    /// Translate all lyric lines in one batch and store results keyed by their
    /// KaraokeItem index (so the view can render each under its line).
    private func runTranslation(_ session: TranslationSession) async {
        let items = buildItems(from: lyricsState.lines)
        let lineItems: [(Int, String)] = items.enumerated().compactMap { index, item in
            if case .lyric(let line) = item { return (index, line.text) }
            return nil
        }
        guard !lineItems.isEmpty else { return }

        let requests = lineItems.map {
            TranslationSession.Request(sourceText: $0.1, clientIdentifier: String($0.0))
        }
        do {
            let responses = try await session.translations(from: requests)
            var map: [Int: String] = [:]
            for response in responses {
                if let id = response.clientIdentifier, let index = Int(id) {
                    map[index] = response.targetText
                }
            }
            lyricsState.translations = map
        } catch {
            lyricsState.translations = [:]
        }
    }

    // Collapse + hide controls as Liquid Glass buttons (macOS 26+), grouped in a
    // GlassEffectContainer so the two circles blend/morph. Falls back to a subtle
    // material circle on older macOS where Liquid Glass isn't available.
    @ViewBuilder
    private var controlButtons: some View {
        let cluster = HStack(spacing: 8) {
            ControlButton(
                systemName: lyricsState.isMinimized ? "chevron.down" : "chevron.up",
                accessibilityLabel: lyricsState.isMinimized ? "Expand" : "Collapse"
            ) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    lyricsState.isMinimized.toggle()
                }
            }
            ControlButton(systemName: "eye.slash", accessibilityLabel: "Hide lyrics") {
                lyricsState.isManuallyHidden = true
            }
        }

        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 8) { cluster }
        } else {
            cluster
        }
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

/// A compact circular icon button styled as Liquid Glass on macOS 26+.
private struct ControlButton: View {
    let systemName: String
    var accessibilityLabel: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 26, height: 26)
                .contentShape(.circle)
        }
        .accessibilityLabel(accessibilityLabel)
        .glassControlStyle()
    }
}

private extension View {
    /// Liquid Glass button styling on macOS 26+, with a material-circle fallback
    /// for earlier systems where the glass APIs are unavailable.
    @ViewBuilder
    func glassControlStyle() -> some View {
        if #available(macOS 26.0, *) {
            self
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.small)
        } else {
            self
                .buttonStyle(.plain)
                .background(.ultraThinMaterial, in: Circle())
        }
    }
}
