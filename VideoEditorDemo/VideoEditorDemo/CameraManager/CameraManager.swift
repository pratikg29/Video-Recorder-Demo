//
//  CameraManager.swift
//  VideoEditorDemo
//
//  Created by Pratik Gadhesariya on 05/11/24.
//

import AVFoundation
import CoreImage
import UIKit
import Photos

enum CameraError: Error {
    case captureSessionSetupFailed
    case deviceNotFound
    case invalidPermissions
    case recordingFailed
    case saveToGalleryFailed
    case videoFileNotFound
    case videoFileInvalid
}

protocol CameraManagerDelegate: AnyObject {
    func cameraManager(_ manager: CameraManager, didOutput pixelBuffer: CVPixelBuffer)
}

class CameraManager: NSObject {
    private let session = AVCaptureSession()
    private var device: AVCaptureDevice?
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var audioDataOutput: AVCaptureAudioDataOutput?
    
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    private(set) var isRecording = false
    private(set) var recordingURL: URL?
    private var videoStartTime: CMTime?
    
    weak var delegate: CameraManagerDelegate?
    private let metalRenderer: MetalRenderer
    private let processQueue = DispatchQueue(label: "com.camera.process")
    
    private(set) var flashMode: AVCaptureDevice.FlashMode = .off
    private(set) var currentZoomFactor: CGFloat = 1.0
    private(set) var currentPosition: AVCaptureDevice.Position = .back
    
    init(metalRenderer: MetalRenderer) {
        self.metalRenderer = metalRenderer
        super.init()
    }
    
    func requestPermissions() async throws {
        // Check video permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                throw CameraError.invalidPermissions
            }
        default:
            throw CameraError.invalidPermissions
        }
        
        // Check audio permission
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .audio) else {
                throw CameraError.invalidPermissions
            }
        default:
            throw CameraError.invalidPermissions
        }
    }
    
    func setupCamera() throws {
        session.beginConfiguration()
        session.sessionPreset = .hd1920x1080
        
        // Setup video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.deviceNotFound
        }
        
        guard let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            throw CameraError.captureSessionSetupFailed
        }
        
        guard session.canAddInput(videoInput) else {
            throw CameraError.captureSessionSetupFailed
        }
        
        session.addInput(videoInput)
        self.videoDeviceInput = videoInput
        self.device = videoDevice
        
        // Setup audio input
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            throw CameraError.deviceNotFound
        }
        
        guard let audioInput = try? AVCaptureDeviceInput(device: audioDevice) else {
            throw CameraError.captureSessionSetupFailed
        }
        
        guard session.canAddInput(audioInput) else {
            throw CameraError.captureSessionSetupFailed
        }
        
        session.addInput(audioInput)
        self.audioDeviceInput = audioInput
        
        // Setup video output
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput.setSampleBufferDelegate(self, queue: processQueue)
        
        guard session.canAddOutput(videoOutput) else {
            throw CameraError.captureSessionSetupFailed
        }
        
        session.addOutput(videoOutput)
        self.videoDataOutput = videoOutput
        
        // Setup audio output
        let audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(self, queue: processQueue)
        
        guard session.canAddOutput(audioOutput) else {
            throw CameraError.captureSessionSetupFailed
        }
        
        session.addOutput(audioOutput)
        self.audioDataOutput = audioOutput
        
        // Set initial video orientation and mirroring
        if let connection = videoDataOutput?.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = currentPosition == .front
            }
        }
        
        session.commitConfiguration()
    }
    
    func startSession() {
        guard !session.isRunning else { return }
        DispatchQueue.global().async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func stopSession() {
        guard session.isRunning else { return }
        session.stopRunning()
    }
    
    func startRecording() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "recording-\(Date().timeIntervalSince1970).mov"
        let videoURL = tempDir.appendingPathComponent(fileName)
        
        // Remove any existing file
        try? FileManager.default.removeItem(at: videoURL)
        
        guard let assetWriter = try? AVAssetWriter(url: videoURL, fileType: .mov) else {
            throw CameraError.recordingFailed
        }
        
        // Setup video input
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1080,
            AVVideoHeightKey: 1920,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 10_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: 30,
                AVVideoExpectedSourceFrameRateKey: 30
            ]
        ]
        
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        
        guard assetWriter.canAdd(videoInput) else {
            throw CameraError.recordingFailed
        }
        
        // Setup pixel buffer adaptor
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: 1080,
            kCVPixelBufferHeightKey as String: 1920,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )
        
        // Setup audio input
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000
        ]
        
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput.expectsMediaDataInRealTime = true
        
        guard assetWriter.canAdd(audioInput) else {
            throw CameraError.recordingFailed
        }
        
        assetWriter.add(videoInput)
        assetWriter.add(audioInput)
        
        self.assetWriter = assetWriter
        self.videoInput = videoInput
        self.audioInput = audioInput
        self.pixelBufferAdaptor = adaptor
        self.recordingURL = videoURL
        
        assetWriter.startWriting()
        isRecording = true
    }
    
    func stopRecording() async throws {
        guard let assetWriter = assetWriter else { return }
        
        isRecording = false
        
        return try await withCheckedThrowingContinuation { continuation in
            processQueue.async { [weak self] in
                self?.videoInput?.markAsFinished()
                self?.audioInput?.markAsFinished()
                
                assetWriter.finishWriting {
                    if assetWriter.status == .completed {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: CameraError.recordingFailed)
                    }
                    
                    self?.resetRecording()
                }
            }
        }
    }
    
    private func resetRecording() {
        assetWriter = nil
        videoInput = nil
        audioInput = nil
        pixelBufferAdaptor = nil
        videoStartTime = nil
    }
    
    func saveToGallery() async throws {
        guard let videoURL = recordingURL else { return }
        
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
        }
    }
    
    func setZoom(factor: CGFloat) {
        guard let device = device else { return }
        
        do {
            try device.lockForConfiguration()
            let newFactor = max(1.0, min(factor, device.maxAvailableVideoZoomFactor))
            device.videoZoomFactor = newFactor
            currentZoomFactor = newFactor
            device.unlockForConfiguration()
        } catch {
            print("Error setting zoom: \(error)")
        }
    }
    
    func toggleFlash() {
        guard let device = device else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.hasTorch {
                if device.torchMode == .off {
                    try device.setTorchModeOn(level: 1.0)
                    flashMode = .on
                } else {
                    device.torchMode = .off
                    flashMode = .off
                }
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error toggling flash: \(error)")
        }
    }
    
    func flipCamera() throws {
        guard let currentInput = videoDeviceInput else { return }
        
        // Get new device position
        let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
        
        // Get new device
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                        for: .video,
                                                        position: newPosition) else {
            throw CameraError.deviceNotFound
        }
        
        // Get new input
        guard let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            throw CameraError.captureSessionSetupFailed
        }
        
        // Configure session
        session.beginConfiguration()
        
        // Remove existing input
        session.removeInput(currentInput)
        
        // Add new input
        guard session.canAddInput(videoInput) else {
            session.addInput(currentInput)
            session.commitConfiguration()
            throw CameraError.captureSessionSetupFailed
        }
        
        session.addInput(videoInput)
        
        // Update video orientation
        if let connection = videoDataOutput?.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = newPosition == .front
            }
        }
        
        session.commitConfiguration()
        
        // Update stored properties
        self.videoDeviceInput = videoInput
        self.device = videoDevice
        self.currentPosition = newPosition
        
        // Reset zoom when flipping
        currentZoomFactor = 1.0
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        if output is AVCaptureVideoDataOutput {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            // Pass frame to delegate for preview
            delegate?.cameraManager(self, didOutput: pixelBuffer)
            
            // Handle video recording
            handleVideoBuffer(pixelBuffer, timestamp: timestamp)
        } else if output is AVCaptureAudioDataOutput {
            handleAudioBuffer(sampleBuffer, timestamp: timestamp)
        }
    }
    
    private func handleVideoBuffer(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        guard isRecording,
              let assetWriter = assetWriter,
              let videoInput = videoInput,
              let adaptor = pixelBufferAdaptor else {
            return
        }
        
        if videoStartTime == nil {
            videoStartTime = timestamp
            assetWriter.startSession(atSourceTime: timestamp)
        }
        
        guard videoInput.isReadyForMoreMediaData else { return }
        
        var outputPixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &outputPixelBuffer)
        
        guard let outputPixelBuffer = outputPixelBuffer else { return }
        
        // Process frame with Metal
        CVPixelBufferLockBaseAddress(outputPixelBuffer, [])
        
        let commandBuffer = metalRenderer.commandQueue.makeCommandBuffer()
        var cvTextureOut: CVMetalTexture?
        
        CVMetalTextureCacheCreateTextureFromImage(
            nil,
            metalRenderer.textureCache,
            outputPixelBuffer,
            nil,
            .bgra8Unorm,
            CVPixelBufferGetWidth(outputPixelBuffer),
            CVPixelBufferGetHeight(outputPixelBuffer),
            0,
            &cvTextureOut
        )
        
        if let cvTextureOut = cvTextureOut,
           let outputTexture = CVMetalTextureGetTexture(cvTextureOut) {
            try? metalRenderer.renderToTexture(
                pixelBuffer: pixelBuffer,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer!
            )
            
            commandBuffer?.commit()
            commandBuffer?.waitUntilCompleted()
        }
        
        CVPixelBufferUnlockBaseAddress(outputPixelBuffer, [])
        
        if !adaptor.append(outputPixelBuffer, withPresentationTime: timestamp) {
            print("Failed to append video pixel buffer")
        }
    }
    
    private func handleAudioBuffer(_ sampleBuffer: CMSampleBuffer, timestamp: CMTime) {
        guard isRecording,
              let audioInput = audioInput,
              audioInput.isReadyForMoreMediaData else {
            return
        }
        
        if !audioInput.append(sampleBuffer) {
            print("Failed to append audio sample buffer")
        }
    }
}
