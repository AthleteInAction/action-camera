//
//  ActionCameraManager.swift
//  action-camera-manager
//
//  Created by Will Robinson on 10/7/26.
//

@preconcurrency import AVKit


public enum ActionCamera {
    @MainActor
    @Observable
    public class Manager: NSObject {
        // MARK: nonisolated -
        nonisolated public let session = AVCaptureSession()
        nonisolated private let sessionQueue = DispatchQueue(label: "action-camera-manager.camera-queue", qos: .userInitiated)
        nonisolated private let videoOutput = AVCaptureMovieFileOutput()
        nonisolated private let photoOutput = AVCapturePhotoOutput()
        
        
        // MARK: @MainActor -
        /// PUBLIC -------------------------------------------------------------
        public var accessGranted: Bool = true
        public var isRunning: Bool = false
        public var isRecording: Bool = false
        public var startZoomFactor: CGFloat?
        public var maxZoomFactor: CGFloat = 1.0
        public var fpsInUse: Int?
        public var widthInUse: Int?
        public var heightInUse: Int?
        public var elapsedTime: TimeInterval?
        public var videoPath: URL?
        public var recordingPreferredHeight: Int = 1080 /// 1080p
        public var recordingPreferredFPS: Int = 60 /// 60 fps
        /// PRIVATE ------------------------------------------------------------
        private var monitorTask: Task<Void, Never>?
        private var photoProcessor: PhotoProcessor?
        
        
        public var videoFormatText: String? {
            var strings: [String] = []
            
            if let heightInUse {
                strings.append("\(heightInUse)p")
            }
            
            if let fpsInUse {
                strings.append("\(fpsInUse)")
            }
            
            if !strings.isEmpty { return strings.joined(separator: " ") }
            
            return nil
        }
        
        
        public var videoKText: String? {
            var strings: [String] = []
            
            if let heightInUse {
                if heightInUse == 2160 {
                    strings.append("4K")
                } else {
                    strings.append("\(heightInUse)p")
                }
            }
            
            if let fpsInUse {
                strings.append("\(fpsInUse)")
            }
            
            if !strings.isEmpty { return strings.joined(separator: " ") }
            
            return nil
        }
        
        
        public func startSession() async {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            
            /// Switf does not allow "status == .authorized || await AVCaptureDevice.requestAccess(for: .video)"
            /// the below alternate works
            if status != .authorized, !(await AVCaptureDevice.requestAccess(for: .video)) {
                accessGranted = false
                return
            }
            
            accessGranted = true
            
            setupAndStartSession()
        }
        
        
        public func setupAndStartSession() {
            guard !session.isRunning else { return }
            
            sessionQueue.async { [weak self] in
                guard let self else { return }
                
                guard
                    let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                    let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice)
                else { return }
                
                self.session.beginConfiguration()
                
                defer { self.session.commitConfiguration() }
                
                guard
                    self.session.canAddInput(videoDeviceInput),
                    self.session.canAddOutput(self.videoOutput)
                else { return }
                
                self.session.addInput(videoDeviceInput)
                self.session.addOutput(self.videoOutput)
                
                if self.session.canAddOutput(self.photoOutput) {
                    self.photoOutput.maxPhotoQualityPrioritization = .speed
                    self.session.addOutput(self.photoOutput)
                }
                
                if let connection = self.videoOutput.connection(with: .video) {
                    let videoSettings: [String: Any] = [
                        AVVideoCodecKey: AVVideoCodecType.h264,
                        AVVideoCompressionPropertiesKey: [
                            AVVideoAverageBitRateKey: 6_000_000,
                            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                        ]
                    ]
                    
                    self.videoOutput.setOutputSettings(videoSettings, for: connection)
                }
            }
            
            setVideoOutput()
            
            startRunning()
        }
        
        
        public func stopSession() {
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
            stopMonitoringTime()
            stopRunning()
        }
        
        
        private func startRunning() {
            sessionQueue.async { [weak self] in
                guard let self, !self.session.isRunning else { return }
                self.session.startRunning()
                Task { @MainActor in
                    self.isRunning = true
                }
            }
        }
        
        
        private func stopRunning() {
            sessionQueue.async { [weak self] in
                guard let self, self.session.isRunning else { return }
                self.session.stopRunning()
                Task { @MainActor in
                    self.isRunning = false
                }
            }
        }
        
        
        public func setVideoOutput() {
            guard let _format = Self.formatFor(height: recordingPreferredHeight, fps: recordingPreferredFPS) else {
                print("[ACM][ERROR] could not find a video format")
                return
            }
            
            let fpsDouble = Double(recordingPreferredFPS)
            let format = _format
            
            sessionQueue.async { [weak self] in
                guard let self else { return }
                
                guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
                
                do {
                    try videoDevice.lockForConfiguration()
                } catch {
                    print("[ACM][ERROR] could not lock for configuration")
                    return
                }
                
                defer { videoDevice.unlockForConfiguration() }
                
                videoDevice.focusMode    = .continuousAutoFocus
                videoDevice.activeFormat = format
                
                let fps = CMTime(value: 1, timescale: CMTimeScale(fpsDouble))
                videoDevice.activeVideoMinFrameDuration = fps
                videoDevice.activeVideoMaxFrameDuration = fps
                
                let activeFPS     = videoDevice.getActiveFPS
                let widthInUse    = videoDevice.getActiveResolution.width
                let heightInUse   = videoDevice.getActiveResolution.height
                let maxZoomFactor = format.systemRecommendedVideoZoomRange?.upperBound ?? 1.0
                
                Task { @MainActor in
                    self.maxZoomFactor = maxZoomFactor
                    self.fpsInUse      = activeFPS
                    self.widthInUse    = widthInUse
                    self.heightInUse   = heightInUse
                }
                
                print(
                    "[VIDEO FORMAT]",
                    "\(format.resolution.width)x\(format.resolution.height)",
                    "::",
                    "\(format.fpsRange.lowerBound)-\(format.fpsRange.upperBound) fps",
                    "::",
                    "Max Zoom:",
                    maxZoomFactor,
                    "::",
                    "FOV:",
                    format.videoFieldOfView
                )
            }
        }
        
        
        public func startRecording(path: URL) {
            guard !videoOutput.isRecording else { return }
            
            setOrientation()
            
            videoOutput.startRecording(to: path, recordingDelegate: self)
        }
        
        
        public func stopRecording() {
            guard videoOutput.isRecording else { return }
            
            videoOutput.stopRecording()
        }
        
        
        private func setOrientation(){
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            
            let videoConnection = videoOutput.connection(with: .video)
            let photoConnection = photoOutput.connection(with: .video)
            
            switch windowScene.interfaceOrientation {
            case .landscapeLeft:
                videoConnection?.videoRotationAngle = 180
                photoConnection?.videoRotationAngle = 180
            case .landscapeRight:
                videoConnection?.videoRotationAngle = 0
                photoConnection?.videoRotationAngle = 0
            default:
                ()
            }
        }
        
        
        private func startMonitoringTime() {
            monitorTask?.cancel()
            monitorTask = nil
            monitorTask = Task {
                while self.videoOutput.isRecording {
                    if Task.isCancelled { break }
                    try? await Task.sleep(for: .seconds(0.1))
                    let elapsedTime: TimeInterval = CMTimeGetSeconds(self.videoOutput.recordedDuration)
                    self.elapsedTime = elapsedTime
                }
                self.elapsedTime = nil
            }
        }
        
        
        private func stopMonitoringTime() {
            monitorTask?.cancel()
            monitorTask = nil
        }
        
        
        public func takePhoto(completion: @escaping (Data?) -> Void) {
            let settings = AVCapturePhotoSettings()

            self.photoProcessor = PhotoProcessor { [weak self] image in
                Task { @MainActor in completion(image) }
                self?.photoProcessor = nil
            }
            
            if let processor = self.photoProcessor {
                setOrientation()
                photoOutput.capturePhoto(with: settings, delegate: processor)
            }
        }
        
        
        public func setZoomFactor(_ zoomFactor: CGFloat) {
            sessionQueue.async { [weak self] in
                guard
                    self != nil,
                    let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                else { return }
                
                do {
                    try videoDevice.lockForConfiguration()
                    videoDevice.videoZoomFactor = zoomFactor
                    videoDevice.unlockForConfiguration()
                } catch {
                    print("[ACM][ERROR] could not lock device for configuration")
                }
            }
        }
    }
}


// MARK: Static Methods -
extension ActionCamera.Manager {
    static func formatFor(height: Int, fps: Int) -> AVCaptureDevice.Format? {
        do {
            let allFormats = try getAvailableFormats()
            
            return allFormats.first(where: {
                $0.resolution.height == height &&
                $0.fpsRange ~= fps
            })
        } catch {
            print("[DEFAULT FORMAT] error", error)
        }
        
        return nil
    }
    
    
    static func getAvailableFormats() throws -> [AVCaptureDevice.Format] {
        let allFormats = try AVCaptureDevice.Format.getAvailableFormats()
            .filter { format in
                format.aspectRatio == 16/9 &&
                (format.fpsRange ~= 30 || format.fpsRange ~= 60) &&
                format.resolution.height >= 720
            }
        
        var formats: [AVCaptureDevice.Format]  = []
        
        for format in allFormats {
            if formats.first(where: {
                $0.resolution == format.resolution &&
                $0.fpsRange == format.fpsRange
            }) == nil {
                formats.append(format)
            }
        }
        
        return formats.sorted { $0.videoMaxZoomFactor > $1.videoMaxZoomFactor }
    }
    
    
    public static func availableFPSForHeight(height: Int) -> [Int]? {
        let fpsOptions: [Int] = [30, 60, 120, 240]
        
        do {
            let formats = try getAvailableFormats().filter {
                $0.resolution.height == height
            }
            
            var finalFPSOptions: [Int] = []
            
            for format in formats {
                for option in fpsOptions {
                    if format.fpsRange ~= option {
                        finalFPSOptions.append(option)
                    }
                }
            }
                
            return Array(Set(finalFPSOptions)).sorted()
        } catch {
            print("[AVAILABLE FPS] error", error)
        }
        
        return nil
    }
    
    
    public static var availableResolutions: [Int]? {
        do {
            let resolutions = try getAvailableFormats().map(\.resolution.height)
            return Array(Set(resolutions)).sorted()
        } catch {
            print("[AVAILABLE RESOLUTIONS] error", error)
        }
        
        return nil
    }
}


// MARK: Delegate Methods -
extension ActionCamera.Manager: AVCaptureFileOutputRecordingDelegate {
    nonisolated public func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        Task { @MainActor in
            self.startMonitoringTime()
            self.isRecording = true
        }
    }
    
    
    nonisolated public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: (any Swift.Error)?) {
        defer {
            Task { @MainActor in
                self.isRecording = false
                self.stopMonitoringTime()
            }
        }
        
        if let error {
            print("[ACM][ERROR]", error)
            return
        }
        
        Task { @MainActor in
            self.videoPath = outputFileURL
        }
    }
}


// MARK: Photo Processor -
extension ActionCamera.Manager {
    class PhotoProcessor: NSObject, AVCapturePhotoCaptureDelegate {
        private let completion: (Data?) -> Void
        

        init(completion: @escaping (Data?) -> Void) {
            self.completion = completion
        }
        
        
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            guard error == nil, let imageData = photo.fileDataRepresentation() else {
                completion(nil)
                return
            }
            completion(imageData)
        }
    }
}
