//
//  VideoOutputDelegate.swift
//  VideoEditorDemo
//
//  Created by Pratik Gadhesariya on 05/11/24.
//

import AVFoundation
import CoreImage
import Metal

protocol VideoOutputDelegate: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    var onFrame: ((CVPixelBuffer) -> Void)? { get set }
    func setAssetWriter(_ writer: AVAssetWriter?,
                       videoInput: AVAssetWriterInput?,
                       audioInput: AVAssetWriterInput?,
                       pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?)
}

//final class DefaultVideoOutputDelegate: NSObject, VideoOutputDelegate {
//    var onFrame: ((CVPixelBuffer) -> Void)?
//    private let metalRenderer: MetalRenderer
//    
//    private var assetWriter: AVAssetWriter?
//    private var videoInput: AVAssetWriterInput?
//    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
//    private var audioInput: AVAssetWriterInput?
//    private var startTime: CMTime?
//    
//    init(metalRenderer: MetalRenderer) {
//        self.metalRenderer = metalRenderer
//        super.init()
//    }
//    
//    func setAssetWriter(_ writer: AVAssetWriter?,
//                       videoInput: AVAssetWriterInput?,
//                       audioInput: AVAssetWriterInput?,
//                       pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?) {
//        self.assetWriter = writer
//        self.videoInput = videoInput
//        self.audioInput = audioInput
//        self.pixelBufferAdaptor = pixelBufferAdaptor
//        self.startTime = nil
//    }
//    
//    func captureOutput(_ output: AVCaptureOutput,
//                      didOutput sampleBuffer: CMSampleBuffer,
//                      from connection: AVCaptureConnection) {
//        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
//        
//        // Pass the frame for preview
//        onFrame?(pixelBuffer)
//        
//        if output is AVCaptureVideoDataOutput {
//            handleVideoSampleBuffer(sampleBuffer, pixelBuffer: pixelBuffer)
//        } else if output is AVCaptureAudioDataOutput {
//            handleAudioSampleBuffer(sampleBuffer)
//        }
//    }
//    
//    private func handleVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer, pixelBuffer: CVPixelBuffer) {
//        guard let assetWriter = assetWriter,
//              assetWriter.status == .writing,
//              let pixelBufferAdaptor = pixelBufferAdaptor else {
//            return
//        }
//        
//        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
//        
//        if startTime == nil {
//            startTime = timestamp
//            assetWriter.startSession(atSourceTime: timestamp)
//        }
//        
//        guard let videoInput = videoInput, videoInput.isReadyForMoreMediaData else { return }
//        
//        // Create output pixel buffer
//        var outputPixelBuffer: CVPixelBuffer?
//        CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferAdaptor.pixelBufferPool!, &outputPixelBuffer)
//        
//        guard let outputPixelBuffer = outputPixelBuffer else { return }
//        
//        // Lock the buffer for writing
//        CVPixelBufferLockBaseAddress(outputPixelBuffer, [])
//        defer {
//            CVPixelBufferUnlockBaseAddress(outputPixelBuffer, [])
//        }
//        
//        // Create a command buffer
//        guard let commandBuffer = metalRenderer.commandQueue.makeCommandBuffer(),
//              let outputTexture = createMetalTexture(from: outputPixelBuffer) else {
//            return
//        }
//        
//        do {
//            // Render with shader effect
//            try metalRenderer.renderToTexture(pixelBuffer: pixelBuffer,
//                                            outputTexture: outputTexture,
//                                            commandBuffer: commandBuffer)
//            
//            commandBuffer.commit()
//            commandBuffer.waitUntilCompleted()
//            
//            // Append the processed frame
//            if !pixelBufferAdaptor.append(outputPixelBuffer, withPresentationTime: timestamp) {
//                print("Failed to append pixel buffer")
//            }
//        } catch {
//            print("Failed to process video frame: \(error)")
//        }
//    }
//    
//    private func createMetalTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
//        var cvTextureOut: CVMetalTexture?
//        let width = CVPixelBufferGetWidth(pixelBuffer)
//        let height = CVPixelBufferGetHeight(pixelBuffer)
//        
//        CVMetalTextureCacheCreateTextureFromImage(nil,
//                                                metalRenderer.textureCache,
//                                                pixelBuffer,
//                                                nil,
//                                                .bgra8Unorm,
//                                                width,
//                                                height,
//                                                0,
//                                                &cvTextureOut)
//        
//        return cvTextureOut.flatMap { CVMetalTextureGetTexture($0) }
//    }
//    
//    private func handleAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
//        guard let assetWriter = assetWriter,
//              let audioInput = audioInput,
//              audioInput.isReadyForMoreMediaData,
//              assetWriter.status == .writing else {
//            return
//        }
//        
//        audioInput.append(sampleBuffer)
//    }
//    
//    func reset() {
//        assetWriter = nil
//        videoInput = nil
//        audioInput = nil
//        pixelBufferAdaptor = nil
//        startTime = nil
//    }
//}



final class DefaultVideoOutputDelegate: NSObject, VideoOutputDelegate {
    var onFrame: ((CVPixelBuffer) -> Void)?
    private let metalRenderer: MetalRenderer
    
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var audioInput: AVAssetWriterInput?
    private var startTime: CMTime?
    private var sessionStarted = false
    
    init(metalRenderer: MetalRenderer) {
        self.metalRenderer = metalRenderer
        super.init()
    }
    
    func setAssetWriter(_ writer: AVAssetWriter?,
                       videoInput: AVAssetWriterInput?,
                       audioInput: AVAssetWriterInput?,
                       pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?) {
        self.assetWriter = writer
        self.videoInput = videoInput
        self.audioInput = audioInput
        self.pixelBufferAdaptor = pixelBufferAdaptor
        self.startTime = nil
        self.sessionStarted = false
    }
    
    func captureOutput(_ output: AVCaptureOutput,
                      didOutput sampleBuffer: CMSampleBuffer,
                      from connection: AVCaptureConnection) {
        guard let assetWriter = assetWriter else { return }
        
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        // Initialize session timing if needed
        if startTime == nil {
            startTime = timestamp
            assetWriter.startSession(atSourceTime: timestamp)
            sessionStarted = true
        }
        
        if output is AVCaptureVideoDataOutput {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            onFrame?(pixelBuffer)
            handleVideoSampleBuffer(sampleBuffer, pixelBuffer: pixelBuffer)
        } else if output is AVCaptureAudioDataOutput {
            handleAudioSampleBuffer(sampleBuffer)
        }
    }
    
    private func handleVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer, pixelBuffer: CVPixelBuffer) {
        guard let assetWriter = assetWriter,
              assetWriter.status == .writing,
              let videoInput = videoInput,
              videoInput.isReadyForMoreMediaData,
              let pixelBufferAdaptor = pixelBufferAdaptor,
              sessionStarted,
              let startTime = startTime else {
            return
        }
        
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let relativeTime = CMTimeSubtract(timestamp, startTime)
        
        autoreleasepool {
            // Create output pixel buffer
            var outputPixelBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferAdaptor.pixelBufferPool!, &outputPixelBuffer)
            
            guard let outputPixelBuffer = outputPixelBuffer else { return }
            
            // Lock the buffer for writing
            CVPixelBufferLockBaseAddress(outputPixelBuffer, [])
            defer {
                CVPixelBufferUnlockBaseAddress(outputPixelBuffer, [])
            }
            
            // Create a command buffer
            guard let commandBuffer = metalRenderer.commandQueue.makeCommandBuffer(),
                  let outputTexture = createMetalTexture(from: outputPixelBuffer) else {
                return
            }
            
            do {
                // Render with shader effect
                try metalRenderer.renderToTexture(pixelBuffer: pixelBuffer,
                                                outputTexture: outputTexture,
                                                commandBuffer: commandBuffer)
                
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                
                // Append the processed frame
                if !pixelBufferAdaptor.append(outputPixelBuffer, withPresentationTime: relativeTime) {
                    print("Failed to append pixel buffer")
                }
            } catch {
                print("Failed to process video frame: \(error)")
            }
        }
    }
    
    private func handleAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let assetWriter = assetWriter,
              assetWriter.status == .writing,
              let audioInput = audioInput,
              audioInput.isReadyForMoreMediaData,
              sessionStarted,
              let startTime = startTime else {
            return
        }
        
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let relativeTime = CMTimeSubtract(timestamp, startTime)
        
        // Check if we have a valid audio sample buffer
        guard CMSampleBufferDataIsReady(sampleBuffer) else {
            print("Audio sample buffer is not ready")
            return
        }
        
        // Create a copy of the sample buffer with the adjusted timestamp
        var timingInfo = CMSampleTimingInfo(
            duration: CMSampleBufferGetDuration(sampleBuffer),
            presentationTimeStamp: relativeTime,
            decodeTimeStamp: .invalid
        )
        
        var copyBuffer: CMSampleBuffer?
        var audioBufferCopy = sampleBuffer
        
        CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: audioBufferCopy,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleBufferOut: &copyBuffer
        )
        
        if let copyBuffer = copyBuffer {
            if !audioInput.append(copyBuffer) {
                print("Failed to append audio buffer")
            }
        }
    }
    
    private func createMetalTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        var cvTextureOut: CVMetalTexture?
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        CVMetalTextureCacheCreateTextureFromImage(nil,
                                                metalRenderer.textureCache,
                                                pixelBuffer,
                                                nil,
                                                .bgra8Unorm,
                                                width,
                                                height,
                                                0,
                                                &cvTextureOut)
        
        return cvTextureOut.flatMap { CVMetalTextureGetTexture($0) }
    }
    
    func reset() {
        assetWriter = nil
        videoInput = nil
        audioInput = nil
        pixelBufferAdaptor = nil
        startTime = nil
        sessionStarted = false
    }
}
