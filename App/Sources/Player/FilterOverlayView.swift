import SwiftUI
import UIKit
import ZettaCore

/// The scanlines, the dark corners, the tube edge, and the grain of a filter, drawn on top of
/// the video. The tint of a colour filter multiplies the picture under it. The adjust filter of
/// VLC does the rest of the colour change. The scanlines and the corners are drawn one time.
/// Only the grain moves.
struct FilterOverlayView: View {
    let filter: VideoFilter

    var body: some View {
        ZStack {
            if let tint = VideoAdjust.of(filter)?.tint {
                Color(red: Double(tint[0]), green: Double(tint[1]), blue: Double(tint[2])).blendMode(.multiply)
            }
            if filter.scanlines > 0 || filter.vignette > 0 || filter.tube {
                Canvas { context, size in draw(&context, size) }
            }
            if filter.grain > 0 {
                GrainView(strength: filter.grain)
            }
        }
        .allowsHitTesting(false)
    }

    private func draw(_ context: inout GraphicsContext, _ size: CGSize) {
        let full = CGRect(origin: .zero, size: size)
        if filter.scanlines > 0 {
            // A dark line for each line of the old picture, as on a tube screen.
            let step = CGFloat(FilterOverlay.scanlineStep(height: Float(size.height)))
            let thickness = step * CGFloat(FilterOverlay.scanlineThickness)
            var lines = Path()
            var y: CGFloat = 0
            while y < size.height {
                lines.addRect(CGRect(x: 0, y: y - thickness / 2, width: size.width, height: thickness))
                y += step
            }
            context.fill(lines, with: .color(.black.opacity(Double(filter.scanlines))))
        }
        if filter.vignette > 0 {
            let gradient = Gradient(stops: [
                .init(color: .clear, location: CGFloat(FilterOverlay.vignetteClearStop)),
                .init(color: .black.opacity(Double(filter.vignette)), location: 1),
            ])
            let radius = max(size.width, size.height) * CGFloat(FilterOverlay.vignetteRadius)
            context.fill(Path(full), with: .radialGradient(gradient, center: CGPoint(x: size.width / 2, y: size.height / 2),
                                                           startRadius: 0, endRadius: radius))
        }
        if filter.tube {
            // A tube screen has round corners and a soft shine at the top of its glass.
            let shine = Gradient(stops: [
                .init(color: .white.opacity(Double(FilterOverlay.tubeShineOpacity)), location: 0),
                .init(color: .clear, location: CGFloat(FilterOverlay.tubeShineEnd)),
            ])
            context.fill(Path(full), with: .linearGradient(shine, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            let radius = min(size.width, size.height) * CGFloat(FilterOverlay.tubeCornerRadius)
            var edge = Path(full)
            edge.addRoundedRect(in: full, cornerSize: CGSize(width: radius, height: radius))
            context.fill(edge, with: .color(.black), style: FillStyle(eoFill: true))
        }
    }
}

/// The film grain: one image of noise that repeats over the screen and moves to a new place
/// a few times a second.
private struct GrainView: View {
    let strength: Float
    @State private var image: Image?

    var body: some View {
        TimelineView(.periodic(from: .now, by: Double(FilterOverlay.grainIntervalMs) / 1000)) { timeline in
            Canvas { context, size in
                guard let image else { return }
                let step = Int(timeline.date.timeIntervalSinceReferenceDate * 1000) / FilterOverlay.grainIntervalMs
                var random = SeededRandom(seed: UInt64(truncatingIfNeeded: step))
                let side = CGFloat(FilterOverlay.grainSize)
                let origin = CGPoint(x: -CGFloat(random.next() % UInt64(FilterOverlay.grainSize)),
                                     y: -CGFloat(random.next() % UInt64(FilterOverlay.grainSize)))
                context.fill(Path(CGRect(x: 0, y: 0, width: size.width + side, height: size.height + side)),
                             with: .tiledImage(image, origin: origin))
            }
        }
        .onAppear { image = Self.noise(strength) }
    }

    /// Grey pixels with a random opacity of at most `strength`. The same seed gives the same grain.
    private static func noise(_ strength: Float) -> Image? {
        let side = FilterOverlay.grainSize
        var random = SeededRandom(seed: 7)
        var pixels = [UInt32](repeating: 0, count: side * side)
        for i in pixels.indices {
            let value = UInt32(random.next() % 256)
            let alpha = UInt32(Float(random.next() % 1000) / 1000 * strength * 255)
            // The image keeps each colour multiplied by its opacity.
            let grey = value * alpha / 255
            pixels[i] = alpha << 24 | grey << 16 | grey << 8 | grey
        }
        let info = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        let made = pixels.withUnsafeMutableBytes { buffer in
            CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info)?.makeImage()
        }
        return made.map { Image(uiImage: UIImage(cgImage: $0, scale: 1, orientation: .up)) }
    }
}

/// A small random number generator with a seed, so that the grain is the same each time.
private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        var z = state
        z = (z ^ (z >> 33)) &* 0xFF51_AFD7_ED55_8CCD
        return z ^ (z >> 33)
    }
}
