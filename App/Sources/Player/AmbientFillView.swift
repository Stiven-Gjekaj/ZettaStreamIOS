import SwiftUI

/// The blurred colours of the video in the side bars, like the ambient mode of YouTube.
/// VLC draws the bars black, so the fill goes on top of the video, with a hole for the picture.
/// The fill changes with no fade: a fade draws the full screen again for each step.
struct AmbientFillView: View {
    let image: UIImage?
    let picture: CGRect?

    var body: some View {
        if let image, let picture {
            ZStack {
                Image(uiImage: image).resizable().interpolation(.high)
                // A dark layer keeps the eye on the video.
                Color.black.opacity(0.25)
            }
            .mask {
                GeometryReader { geometry in
                    Path { path in
                        path.addRect(CGRect(origin: .zero, size: geometry.size))
                        path.addRect(picture)
                    }
                    .fill(style: FillStyle(eoFill: true))
                }
            }
            .allowsHitTesting(false)
        }
    }
}
