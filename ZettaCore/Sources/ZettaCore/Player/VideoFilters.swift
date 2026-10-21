import Foundation

/// A look for the video. The overlays (scanlines, vignette, grain) are drawn on top of the
/// video and cost almost nothing. A colour change (`colour` is true) changes each pixel of
/// each frame on the graphics chip, so it uses more power.
/// The raw value is the name that the Android app saves.
public enum VideoFilter: String, Hashable, Sendable, CaseIterable {
    case none = "None"
    case crt = "Crt"
    case vhs = "Vhs"
    case vintage = "Vintage"
    case blackWhite = "BlackWhite"

    public var label: String {
        switch self {
        case .none: return "None"
        case .crt: return "CRT"
        case .vhs: return "VHS"
        case .vintage: return "Vintage film"
        case .blackWhite: return "Black and white"
        }
    }

    /// True when the filter changes the colours with a matrix.
    public var colour: Bool {
        switch self {
        case .none, .crt: return false
        case .vhs, .vintage, .blackWhite: return true
        }
    }

    /// The opacity of the black scanlines, from 0 to 1. Zero draws no lines.
    public var scanlines: Float {
        switch self {
        case .crt: return 0.5
        case .vhs: return 0.14
        default: return 0
        }
    }

    /// The opacity of the black at the corners, from 0 to 1. Zero draws no vignette.
    public var vignette: Float {
        switch self {
        case .none: return 0
        case .crt: return 0.8
        case .vhs: return 0.3
        case .vintage: return 0.6
        case .blackWhite: return 0.25
        }
    }

    /// The highest opacity of a grain pixel, from 0 to 1. Zero draws no grain.
    public var grain: Float {
        switch self {
        case .vhs: return 0.10
        case .vintage: return 0.14
        default: return 0
        }
    }

    /// True for the rounded black edge and the glass shine of a tube screen.
    public var tube: Bool { self == .crt }
}

/// The sizes of the overlays, so that the app draws them as the Android app does.
public enum FilterOverlay {
    /// The number of scanlines over the height of the screen, about as many as on an old TV picture.
    public static let scanlineCount: Float = 270

    /// The distance between two scanlines. The lines follow the size of the screen,
    /// so that they show from a sofa also on a large TV. It is at least 3 points.
    public static func scanlineStep(height: Float) -> Float { max(height / scanlineCount, 3) }

    /// The thickness of one scanline, as a part of the step.
    public static let scanlineThickness: Float = 0.45

    /// The vignette is a radial gradient from the centre. It is clear up to this part of
    /// the radius, then it goes to black with the opacity of the filter at the radius.
    public static let vignetteClearStop: Float = 0.5

    /// The radius of the vignette, as a part of the longer side of the screen.
    public static let vignetteRadius: Float = 0.6

    /// The radius of the round corners of the tube edge, as a part of the shorter side.
    public static let tubeCornerRadius: Float = 0.07

    /// The shine of the tube is white with this opacity at the top. It is clear at
    /// `tubeShineEnd` of the height.
    public static let tubeShineOpacity: Float = 0.07
    public static let tubeShineEnd: Float = 0.35

    /// The side of the square grain image. The image repeats over the screen.
    public static let grainSize = 128

    /// The time between two positions of the grain. The grain moves 8 times a second.
    public static let grainIntervalMs = 125
}

/// A colour matrix of a filter. A matrix has three rows of four numbers: the red, the
/// green, and the blue result, each from the red, green, and blue input and an added value.
/// Colours go from 0 to 1. Alpha does not change.
public struct ColourMatrix: Hashable, Sendable {
    public var rows: [[Float]]

    public init(_ rows: [[Float]]) {
        precondition(rows.count == 3 && rows.allSatisfy { $0.count == 4 }, "A colour matrix has 3 rows of 4 numbers")
        self.rows = rows
    }

    public static let identity = ColourMatrix([[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0]])

    /// The weights of red, green, and blue in the brightness of a colour (Rec. 601).
    static let lr: Float = 0.299
    static let lg: Float = 0.587
    static let lb: Float = 0.114

    public static func saturation(_ s: Float) -> ColourMatrix {
        ColourMatrix([
            [lr * (1 - s) + s, lg * (1 - s), lb * (1 - s), 0],
            [lr * (1 - s), lg * (1 - s) + s, lb * (1 - s), 0],
            [lr * (1 - s), lg * (1 - s), lb * (1 - s) + s, 0],
        ])
    }

    /// A value `c` below 1 makes the darks lighter and the lights darker, around the middle grey.
    public static func contrast(_ c: Float) -> ColourMatrix {
        identity.diagonal(c, added: 0.5 * (1 - c))
    }

    /// Multiplies each colour, for example more red and less blue for a warm look.
    public static func tint(_ r: Float, _ g: Float, _ b: Float) -> ColourMatrix {
        ColourMatrix([[r, 0, 0, 0], [0, g, 0, 0], [0, 0, b, 0]])
    }

    /// Makes black a dark grey and white a light grey, as an old print does.
    public static func fade(lift: Float, top: Float) -> ColourMatrix {
        identity.diagonal(top - lift, added: lift)
    }

    public static let sepia = ColourMatrix([
        [0.393, 0.769, 0.189, 0],
        [0.349, 0.686, 0.168, 0],
        [0.272, 0.534, 0.131, 0],
    ])

    /// The same matrix with `value` on the diagonal and `added` as the added value of each row.
    private func diagonal(_ value: Float, added: Float) -> ColourMatrix {
        var copy = rows
        for i in 0..<3 {
            copy[i][i] = value
            copy[i][3] = added
        }
        return ColourMatrix(copy)
    }

    /// The result of this matrix, then `second`.
    public func then(_ second: ColourMatrix) -> ColourMatrix {
        let first = rows
        return ColourMatrix(second.rows.map { row in
            [
                row[0] * first[0][0] + row[1] * first[1][0] + row[2] * first[2][0],
                row[0] * first[0][1] + row[1] * first[1][1] + row[2] * first[2][1],
                row[0] * first[0][2] + row[1] * first[1][2] + row[2] * first[2][2],
                row[0] * first[0][3] + row[1] * first[1][3] + row[2] * first[2][3] + row[3],
            ]
        })
    }

    /// A mix of `a` and `b`: 0 gives `a`, 1 gives `b`.
    public static func mix(_ a: ColourMatrix, _ b: ColourMatrix, _ t: Float) -> ColourMatrix {
        ColourMatrix(zip(a.rows, b.rows).map { x, y in (0..<4).map { x[$0] * (1 - t) + y[$0] * t } })
    }

    /// The matrix of a filter. A filter that does not change the colours has none.
    public static func of(_ filter: VideoFilter) -> ColourMatrix? {
        switch filter {
        case .none, .crt:
            return nil
        case .vhs:
            return saturation(0.75).then(tint(1.05, 1, 0.9)).then(contrast(0.88)).then(fade(lift: 0.03, top: 1))
        case .vintage:
            return mix(identity, sepia, 0.85).then(contrast(0.9)).then(fade(lift: 0.06, top: 0.95))
        case .blackWhite:
            return saturation(0).then(contrast(1.08))
        }
    }

    /// A colour through this matrix, kept from 0 to 1.
    public func apply(_ r: Float, _ g: Float, _ b: Float) -> [Float] {
        (0..<3).map { i in
            min(max(rows[i][0] * r + rows[i][1] * g + rows[i][2] * b + rows[i][3], 0), 1)
        }
    }

    /// The 4 x 4 matrix in column order, as OpenGL and Metal read it. Alpha does not change.
    /// The added values are in the last column, at the indices 12, 13, and 14.
    public var columnMajor4x4: [Float] {
        var gl = [Float](repeating: 0, count: 16)
        for row in 0..<3 {
            for col in 0..<4 { gl[col * 4 + row] = rows[row][col] }
        }
        gl[15] = 1
        return gl
    }

    /// The vectors of the Core Image filter `CIColorMatrix`, in the order
    /// inputRVector, inputGVector, inputBVector, inputAVector, inputBiasVector.
    /// Each vector has four numbers. This is the 4 x 5 form of the matrix.
    public var coreImageVectors: [[Float]] {
        [
            [rows[0][0], rows[0][1], rows[0][2], 0],
            [rows[1][0], rows[1][1], rows[1][2], 0],
            [rows[2][0], rows[2][1], rows[2][2], 0],
            [0, 0, 0, 1],
            [rows[0][3], rows[1][3], rows[2][3], 0],
        ]
    }
}
