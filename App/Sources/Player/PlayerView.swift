import SwiftUI
import UIKit
import VLCKit

/// The view that VLC draws the video into. It also lets VLC show the video in Picture in Picture.
final class VideoSurface: UIView, VLCPictureInPictureDrawable {
    nonisolated let media = PictureInPictureMedia()
    /// VLC gives the control of Picture in Picture when the video output can use it.
    var onPictureInPictureReady: ((any VLCPictureInPictureWindowControlling) -> Void)?
    var onSize: ((CGSize) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("VideoSurface does not load from a file") }

    override func layoutSubviews() {
        super.layoutSubviews()
        onSize?(bounds.size)
    }

    nonisolated func mediaController() -> any VLCPictureInPictureMediaControlling { media }

    nonisolated func pictureInPictureReady() -> (((any VLCPictureInPictureWindowControlling)?) -> Void)? {
        { [weak self] given in
            guard let given else { return }
            nonisolated(unsafe) let controller = given
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.onPictureInPictureReady?(controller) }
            }
        }
    }
}

/// Puts the video surface of the player into SwiftUI.
struct PlayerVideoView: UIViewRepresentable {
    let surface: VideoSurface

    func makeUIView(context: Context) -> VideoSurface { surface }
    func updateUIView(_ uiView: VideoSurface, context: Context) {}
}
