import Foundation

/// The values of the `adjust` video filter of VLC that come nearest to a colour matrix.
///
/// The Android app changes each pixel with the full matrix. VLC on iOS has no matrix filter,
/// and a Core Image filter on each frame is not possible with VLCKit. The adjust filter has
/// five values: contrast, brightness, saturation, hue, and gamma. It cannot tint a grey, so
/// the tint of the matrix is a separate colour that the app multiplies over the picture.
///
/// The mapping, from the matrix:
/// - The tint is the colour of white through the matrix, divided by its largest part.
///   A tint that is almost grey is no tint.
/// - Contrast and brightness come from the brightness of the greys through the matrix, less
///   the tint. VLC turns contrast around the middle grey, and brightness adds to each grey.
/// - Saturation is the change of the colour strength of six colours, red to magenta.
/// - Hue is the mean turn of those six colours. With almost no colour, hue is 0.
/// - Gamma stays 1, because each matrix is straight.
public struct VideoAdjust: Hashable, Sendable {
    /// From 0 to 2. 1 is no change.
    public var contrast: Float
    /// From 0 to 2. 1 is no change.
    public var brightness: Float
    /// From 0 to 3. 1 is no change, and 0 is grey.
    public var saturation: Float
    /// From -180 to 180 degrees.
    public var hue: Float
    /// From 0.01 to 10. 1 is no change.
    public var gamma: Float
    /// Red, green, and blue from 0 to 1, which multiply the picture after the filter. Nil is no tint.
    public var tint: [Float]?

    public init(contrast: Float = 1, brightness: Float = 1, saturation: Float = 1, hue: Float = 0, gamma: Float = 1, tint: [Float]? = nil) {
        self.contrast = contrast
        self.brightness = brightness
        self.saturation = saturation
        self.hue = hue
        self.gamma = gamma
        self.tint = tint
    }

    /// The values for a filter, or nil for a filter that does not change the colours.
    public static func of(_ filter: VideoFilter) -> VideoAdjust? {
        ColourMatrix.of(filter).map(of)
    }

    public static func of(_ matrix: ColourMatrix) -> VideoAdjust {
        let white = linear(matrix, [1, 1, 1]).map { min(max($0, 0), 1) }
        let top = white.max() ?? 1
        let shade = top > 0 ? white.map { $0 / top } : [1, 1, 1]
        let tinted = (shade.max() ?? 1) - (shade.min() ?? 1) > 0.02
        let tint = tinted ? shade : [1, 1, 1]
        let tintLuma = max(luma(tint), 0.01)

        // The brightness of a grey after the filter, before the tint.
        func grey(_ g: Float) -> Float { luma(linear(matrix, [g, g, g])) / tintLuma }
        let contrast = grey(1) - grey(0)
        let brightness = 1 + grey(0) - 0.5 * (1 - contrast)

        var ratios: [Float] = []
        var turns: [Float] = []
        for colour in testColours {
            let out = zip(linear(matrix, colour), tint).map { $0 / $1 }
            let (cb, cr) = chroma(colour)
            let (ob, or) = chroma(out)
            let strength = (cb * cb + cr * cr).squareRoot()
            ratios.append((ob * ob + or * or).squareRoot() / strength)
            var turn = (atan2(or, ob) - atan2(cr, cb)) * 180 / .pi
            if turn > 180 { turn -= 360 }
            if turn < -180 { turn += 360 }
            turns.append(turn)
        }
        let saturation = ratios.reduce(0, +) / Float(ratios.count)
        let hue = saturation < 0.05 ? 0 : turns.reduce(0, +) / Float(turns.count)
        return VideoAdjust(
            contrast: min(max(contrast, 0), 2),
            brightness: min(max(brightness, 0), 2),
            saturation: min(max(saturation, 0), 3),
            hue: min(max(hue, -180), 180),
            gamma: 1,
            tint: tinted ? tint : nil
        )
    }

    /// The brightness of a grey `g` after the adjust filter of VLC and the tint, from 0 to 1.
    public func grey(_ g: Float) -> Float {
        let adjusted = min(max(contrast * (g - 0.5) + 0.5 + (brightness - 1), 0), 1)
        return adjusted * Self.luma(tint ?? [1, 1, 1])
    }

    /// Six colours around the colour circle, half strong, so that the matrix does not cut them.
    private static let testColours: [[Float]] = [
        [0.75, 0.25, 0.25], [0.75, 0.75, 0.25], [0.25, 0.75, 0.25],
        [0.25, 0.75, 0.75], [0.25, 0.25, 0.75], [0.75, 0.25, 0.75],
    ]

    /// The matrix with no cut at 0 and 1.
    private static func linear(_ matrix: ColourMatrix, _ c: [Float]) -> [Float] {
        matrix.rows.map { $0[0] * c[0] + $0[1] * c[1] + $0[2] * c[2] + $0[3] }
    }

    static func luma(_ c: [Float]) -> Float {
        ColourMatrix.lr * c[0] + ColourMatrix.lg * c[1] + ColourMatrix.lb * c[2]
    }

    /// The blue and red difference of a colour (Rec. 601), as video keeps them.
    private static func chroma(_ c: [Float]) -> (Float, Float) {
        (-0.168736 * c[0] - 0.331264 * c[1] + 0.5 * c[2], 0.5 * c[0] - 0.418688 * c[1] - 0.081312 * c[2])
    }
}
