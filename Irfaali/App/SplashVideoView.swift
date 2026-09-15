import AVFoundation
import SwiftUI
import UIKit

/// A lightweight, controls-free local video surface used only during cold launch.
/// The bundled asset is played once and completion is driven by AVPlayerItemDidPlayToEndTime.
struct SplashVideoView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerSurfaceView {
        let view = PlayerSurfaceView()
        view.backgroundColor = .black
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerSurfaceView, context: Context) {
        uiView.playerLayer.player = player
    }

    static func dismantleUIView(_ uiView: PlayerSurfaceView, coordinator: ()) {
        uiView.playerLayer.player = nil
    }
}

final class PlayerSurfaceView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}
