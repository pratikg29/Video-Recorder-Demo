//
//  VideoProcessor.swift
//  VideoEditorDemo
//
//  Created by Pratik Gadhesariya on 05/11/24.
//

import Foundation
import AVFoundation
import CoreImage
import Metal
import CoreMedia

class VideoProcessor {
    private let metalRenderer: MetalRenderer
    private let metalDevice: MTLDevice
    private let metalCommandQueue: MTLCommandQueue
    private let textureCache: CVMetalTextureCache
    
    init(metalRenderer: MetalRenderer) throws {
        self.metalRenderer = metalRenderer
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw MetalError.deviceNotFound
        }
        self.metalDevice = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            throw MetalError.commandQueueCreationFailed
        }
        self.metalCommandQueue = commandQueue
        
        var textureCache: CVMetalTextureCache?
        let textureCacheError = CVMetalTextureCacheCreate(nil, nil, metalDevice, nil, &textureCache)
        
        guard textureCacheError == kCVReturnSuccess,
              let unwrappedTextureCache = textureCache else {
            throw MetalError.textureCreationFailed
        }
        
        self.textureCache = unwrappedTextureCache
    }
    
    func processVideoFrame(_ sampleBuffer: CMSampleBuffer, to pixelBufferPool: CVPixelBufferPool?) -> CVPixelBuffer? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let pixelBufferPool = pixelBufferPool else {
            return nil
        }
        
        var outputPixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &outputPixelBuffer)
        
        guard status == kCVReturnSuccess,
              let outputPixelBuffer = outputPixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(outputPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        defer {
            CVPixelBufferUnlockBaseAddress(outputPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        }
        
        guard let outputTexture = createMetalTexture(from: outputPixelBuffer),
              let commandBuffer = metalCommandQueue.makeCommandBuffer() else {
            return nil
        }
        
        do {
            try metalRenderer.renderToTexture(pixelBuffer: pixelBuffer,
                                            outputTexture: outputTexture,
                                            commandBuffer: commandBuffer)
            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            return outputPixelBuffer
        } catch {
            print("Error processing video frame: \(error)")
            return nil
        }
    }
    
    private func createMetalTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        var cvTexture: CVMetalTexture?
        let textureError = CVMetalTextureCacheCreateTextureFromImage(nil,
                                                                    textureCache,
                                                                    pixelBuffer,
                                                                    nil,
                                                                    .bgra8Unorm,
                                                                    width,
                                                                    height,
                                                                    0,
                                                                    &cvTexture)
        
        guard textureError == kCVReturnSuccess,
              let cvTexture = cvTexture,
              let texture = CVMetalTextureGetTexture(cvTexture) else {
            return nil
        }
        
        return texture
    }
}
