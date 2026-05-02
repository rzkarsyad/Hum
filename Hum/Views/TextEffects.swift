import SwiftUI

struct EmphasisAttribute: TextAttribute {}

struct AppearanceEffectRenderer: TextRenderer, Animatable {
    var elapsedTime: TimeInterval
    var elementDuration: TimeInterval
    var totalDuration: TimeInterval

    var spring: Spring {
        .snappy(duration: elementDuration - 0.05, extraBounce: 0.4)
    }

    var animatableData: Double {
        get { elapsedTime }
        set { elapsedTime = newValue }
    }

    init(elapsedTime: TimeInterval, elementDuration: Double = 0.4, totalDuration: TimeInterval) {
        self.elapsedTime = min(elapsedTime, totalDuration)
        self.elementDuration = min(elementDuration, totalDuration)
        self.totalDuration = totalDuration
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let layoutLines = Array(layout)

        // Count emphasized chars per visual line
        let charsPerLine: [Int] = layoutLines.map { line in
            line.reduce(0) { $0 + ($1[EmphasisAttribute.self] != nil ? $1.count : 0) }
        }
        let nonEmptyCount = charsPerLine.filter { $0 > 0 }.count
        let perLineDuration = nonEmptyCount > 0
            ? totalDuration / TimeInterval(nonEmptyCount)
            : totalDuration

        var lineStartTime: TimeInterval = 0

        for (i, line) in layoutLines.enumerated() {
            let lineChars = charsPerLine[i]

            if lineChars == 0 {
                for run in line {
                    var copy = context
                    copy.opacity = UnitCurve.easeIn.value(at: elapsedTime / 0.2)
                    copy.draw(run)
                }
                continue
            }

            let lineElapsed = max(0, elapsedTime - lineStartTime)
            let stagger = delay(count: lineChars, duration: perLineDuration)

            var charIdx = 0
            for run in line {
                if run[EmphasisAttribute.self] != nil {
                    for slice in run {
                        let timeOffset = TimeInterval(charIdx) * stagger
                        let elementTime = max(0, min(lineElapsed - timeOffset, elementDuration))
                        var copy = context
                        draw(slice, at: elementTime, in: &copy)
                        charIdx += 1
                    }
                } else {
                    var copy = context
                    copy.opacity = UnitCurve.easeIn.value(at: lineElapsed / 0.2)
                    copy.draw(run)
                }
            }

            lineStartTime += perLineDuration
        }
    }

    func draw(_ slice: Text.Layout.RunSlice, at time: TimeInterval, in context: inout GraphicsContext) {
        let progress = time / elementDuration
        let opacity = UnitCurve.easeIn.value(at: 1.4 * progress)
        let blurRadius =
            slice.typographicBounds.rect.height / 16 *
            UnitCurve.easeIn.value(at: 1 - progress)
        let translationY = spring.value(
            fromValue: -slice.typographicBounds.descent,
            toValue: 0,
            initialVelocity: 0,
            time: time)
        context.translateBy(x: 0, y: translationY)
        context.addFilter(.blur(radius: blurRadius))
        context.opacity = opacity
        context.draw(slice, options: .disablesSubpixelQuantization)
    }

    private func delay(count: Int, duration: TimeInterval) -> TimeInterval {
        let count = TimeInterval(count)
        let remaining = duration - count * elementDuration
        return max(remaining / (count + 1), (duration - elementDuration) / count)
    }
}

extension Text.Layout {
    var flattenedRuns: some RandomAccessCollection<Text.Layout.Run> {
        self.flatMap { line in line }
    }
}

struct TextTransition: Transition {
    var duration: TimeInterval

    init(duration: TimeInterval = 0.9) {
        self.duration = duration
    }

    static var properties: TransitionProperties {
        TransitionProperties(hasMotion: true)
    }

    func body(content: Content, phase: TransitionPhase) -> some View {
        let elapsedTime = phase.isIdentity ? duration : 0
        let scaledElementDuration = min(duration * 0.44, 0.4)
        let renderer = AppearanceEffectRenderer(
            elapsedTime: elapsedTime,
            elementDuration: scaledElementDuration,
            totalDuration: duration
        )
        content.transaction { transaction in
            if !transaction.disablesAnimations {
                transaction.animation = .linear(duration: duration)
            }
        } body: { view in
            view.textRenderer(renderer)
        }
    }
}
