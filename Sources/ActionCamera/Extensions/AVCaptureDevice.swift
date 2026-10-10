//
//  AVCaptureSession.swift
//  action-camera-manager
//
//  Created by Will Robinson on 10/9/26.
//

import AVKit


internal extension AVCaptureDevice {
    var getActiveFPS: Int? {
        let minFrameDuration = self.activeVideoMinFrameDuration
        
        guard minFrameDuration.timescale > 0 else { return nil }
        
        let fps = Double(minFrameDuration.timescale) / Double(minFrameDuration.value)
        
        return Int(fps)
    }
    
    
    var getActiveResolution: (width: Int, height: Int) {
        let dimensions = CMVideoFormatDescriptionGetDimensions(self.activeFormat.formatDescription)
        return (width: Int(dimensions.width), height: Int(dimensions.height))
    }
}


internal extension AVCaptureDevice.Format {
    static func getAvailableFormats() throws -> [AVCaptureDevice.Format] {
        guard
            let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            videoDevice.isFocusModeSupported(.continuousAutoFocus)
        else { throw ActionCamera.Error(message: "device not found") }
        
        return videoDevice.formats
    }
    
    
    var resolution: (width: Int, height: Int) {
        let dimensions = CMVideoFormatDescriptionGetDimensions(self.formatDescription)
        let width = dimensions.width
        let height = dimensions.height
        
        return (width: Int(width), height: Int(height))
    }
    
    
    var fpsRange: ClosedRange<Int> {
        let range = self.videoSupportedFrameRateRanges.first!
        return (Int(range.minFrameRate)...Int(range.maxFrameRate))
    }
    
    
    var aspectRatio: CGFloat {
        let resolution = self.resolution
        
        let width = CGFloat(resolution.width)
        let height = CGFloat(resolution.height)
        
        return width / height
    }
    
    
    var supportedStabilizationModes: [AVCaptureVideoStabilizationMode] {
        var supportedModes: [AVCaptureVideoStabilizationMode] = []
        
        let allModes: [AVCaptureVideoStabilizationMode] = [
            .off,
            .standard,
            .cinematic,
            .cinematicExtended,
            .previewOptimized
        ]

        for mode in allModes {
            if self.isVideoStabilizationModeSupported(mode) {
                supportedModes.append(mode)
            }
        }
        
        return supportedModes
    }
}
