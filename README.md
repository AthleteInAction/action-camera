# Action Camera

## Overview
A thread-safe camera manager for Swift

## Requirements
- iOS 18+
- macOS 26+

## Limitations

Below limitations are always a work in progress

- only supports 16 / 9 camera formats
- only supports `.builtInWideAngleCamera`
- only supports camera on back of device

## Usage

### Module
```swift
import ActionCamera
```

### Initialization
```swift
let manager = ActionCamera.Manager()
```

## View Example

This example shows a few key features including recording a video, capturing a photo, zooming, and some file save caviats.

```swift
import SwiftUI
import ActionCamera


public struct ExampleCameraView: View {
    private let videoPath: URL = {
        var directory = URL.documentsDirectory
        directory.append(path: "test_video.mp4")
        return directory
    }()
    
    
    @State private var cameraManager = ActionCamera.Manager()
    @State private var photoImage: UIImage?
    @State private var zoomFactor: CGFloat = 1
    
    
    public var body: some View {
        ZStack {
            ActionCamera.PreviewView(session: cameraManager.session)
            
            if let photoImage {
                VStack {
                    Spacer()
                        .frame(height: 40)
                    HStack {
                        Spacer()
                        Image(uiImage: photoImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 140)
                        Spacer()
                            .frame(width: 40)
                    }
                    Spacer()
                }
                .onTapGesture {
                    self.photoImage = nil
                }
            }
            
            VStack(spacing: 20) {
                if cameraManager.isRecording {
                    if let elapsedTime = cameraManager.elapsedTime {
                        Text(mmssSS(time: elapsedTime))
                            .foregroundColor(.white)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                            .background(.red)
                            .cornerRadius(6)
                            .monospacedDigit()
                    }
                } else {
                    Button("TAKE PHOTO"){
                        cameraManager.takePhoto { imageData in
                            if let imageData {
                                self.photoImage = UIImage(data: imageData)
                            }
                        }
                    }
                }
                
                Button(cameraManager.isRecording ? "STOP" : "START RECORDING", role: cameraManager.isRecording ? .destructive : .cancel) {
                    if cameraManager.isRecording {
                        cameraManager.stopRecording()
                        print("Video successfully saved to:", videoPath)
                        
                        /// Deleting the video file for the purpose of this example
                        deleteFile(path: videoPath)
                    } else {
                        /// if the file for a recording already exists, the recording will fail
                        /// so we delete the existing file, if it exists, beforehand in this example
                        /// you will need to manage your own logic for this
                        deleteFile(path: videoPath)
                        
                        cameraManager.startRecording(path: videoPath)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            
            
            if zoomFactor > cameraManager.maxZoomFactor {
                VStack {
                    Spacer()
                    Slider(value: $zoomFactor, in: 1...cameraManager.maxZoomFactor) { isEditing in
                        if !isEditing {
                            cameraManager.setZoomFactor(zoomFactor)
                        }
                    }
                    .frame(width: 300)
                    Spacer().frame(height: 40)
                }
            }
        }
        .ignoresSafeArea()
        .task {
            await cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
    
    
    private func mmssSS(time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
    
    
    private func deleteFile(path: URL) {
        guard FileManager.default.fileExists(atPath: path.path) else { return }
        do {
            try FileManager.default.removeItem(at: path)
            print("File deleted successfully")
        } catch {
            print("Error deleting file")
            print(error)
        }
    }
}
```
