import SwiftUI

struct OnboardingView: View {
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                Text("Welcome to Hum")
                    .font(.title2.bold())

                Text("Floating karaoke lyrics for Apple Music")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 36)
            .padding(.bottom, 28)

            Divider()

            // Steps
            VStack(alignment: .leading, spacing: 20) {
                step(
                    icon: "music.note.list",
                    color: .blue,
                    title: "Play music in Apple Music",
                    detail: "Hum automatically fetches synced lyrics for the current track."
                )
                step(
                    icon: "menubar.rectangle",
                    color: .purple,
                    title: "Lives in your menu bar",
                    detail: "Look for the ♪ icon at the top of your screen to access settings."
                )
                step(
                    icon: "hand.tap",
                    color: .orange,
                    title: "Allow Automation access",
                    detail: "macOS will ask permission to let Hum read what's playing in Apple Music. Tap Allow."
                )
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)

            Divider()

            // CTA
            Button(action: onDone) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(20)
        }
        .frame(width: 380)
        .background(.background)
    }

    private func step(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
