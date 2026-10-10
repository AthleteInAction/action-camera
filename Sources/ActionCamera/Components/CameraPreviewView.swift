//
//  CameraPreviewView.swift
//  action-camera-manager
//
//  Created by Will Robinson on 10/9/26.
//

import SwiftUI
import AVKit
import Combine


extension ActionCamera {
    public struct PreviewView: UIViewRepresentable {
        let session: AVCaptureSession
        
        
        public init(session: AVCaptureSession) {
            self.session = session
        }

        
        public func makeUIView(context: Context) -> VideoPreviewUIView {
            let view = VideoPreviewUIView()
            view.videoPreviewLayer.session = session
            view.videoPreviewLayer.videoGravity = .resizeAspect
            view.startObservingOrientation()
            return view
        }

        
        public func updateUIView(_ uiView: VideoPreviewUIView, context: Context) {
            uiView.updateOrientation()
        }

        
        public class VideoPreviewUIView: UIView {
            override public class var layerClass: AnyClass {
                AVCaptureVideoPreviewLayer.self
            }

            var videoPreviewLayer: AVCaptureVideoPreviewLayer {
                return layer as! AVCaptureVideoPreviewLayer
            }

            private var cancellable: AnyCancellable?

            func startObservingOrientation() {
                cancellable = NotificationCenter.default
                    .publisher(for: UIDevice.orientationDidChangeNotification)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] _ in
                        self?.updateOrientation()
                    }
            }

            override public func layoutSubviews() {
                super.layoutSubviews()
                updateOrientation()
            }

            func updateOrientation() {
                guard let connection = videoPreviewLayer.connection else { return }
                let angle = currentRotationAngle
                
                if connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
            }

            private var currentRotationAngle: CGFloat {
                guard let windowScene = window?.windowScene else { return 90 }

                switch windowScene.interfaceOrientation {
                case .portraitUpsideDown:
                    return 270
                case .landscapeLeft:
                    return 180
                case .landscapeRight:
                    return 0
                default:
                    return 90
                }
            }
        }
    }
}
