//
//  MetalRenderer.swift
//  VideoEditorDemo
//
//  Created by Pratik Gadhesariya on 05/11/24.
//

import Metal
import MetalKit
import CoreVideo
import CoreMedia

class MetalRenderer {
    private let device: MTLDevice
    let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    private let vertexBuffer: MTLBuffer
    private let uniformsBuffer: MTLBuffer
    let textureCache: CVMetalTextureCache
    
    private var pipelineStates: [ShaderType: MTLRenderPipelineState] = [:]
    private var currentShaderType: ShaderType = .beautify
    private var uniforms = ShaderUniforms(time: 0, intensity: 1.0)
    private let startTime = CACurrentMediaTime()
    
    init() throws {
        // Initialize device
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw MetalError.deviceNotFound
        }
        self.device = device
        
        // Initialize command queue
        guard let commandQueue = device.makeCommandQueue() else {
            throw MetalError.commandQueueCreationFailed
        }
        self.commandQueue = commandQueue
        
        // Initialize shader library
        guard let library = try? device.makeDefaultLibrary() else {
            throw MetalError.libraryCreationFailed
        }
        self.library = library
        
        // Create vertex buffer
        let vertices = Vertex.vertices()
        guard let vertexBuffer = device.makeBuffer(bytes: vertices,
                                                 length: vertices.count * MemoryLayout<Vertex>.stride,
                                                 options: []) else {
            throw MetalError.bufferCreationFailed
        }
        self.vertexBuffer = vertexBuffer
        
        // Create uniforms buffer
        guard let uniformsBuffer = device.makeBuffer(length: MemoryLayout<ShaderUniforms>.size,
                                                   options: []) else {
            throw MetalError.bufferCreationFailed
        }
        self.uniformsBuffer = uniformsBuffer
        
        // Create texture cache
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
        guard let unwrappedTextureCache = textureCache else {
            throw MetalError.textureCreationFailed
        }
        self.textureCache = unwrappedTextureCache
        
        // Create pipeline states for each shader type
        try self.initializePipelineStates()
    }
    
    private func initializePipelineStates() throws {
        for shaderType in ShaderType.allCases {
            let pipelineState = try createPipelineState(for: shaderType)
            pipelineStates[shaderType] = pipelineState
        }
    }
    
    private func createPipelineState(for shaderType: ShaderType) throws -> MTLRenderPipelineState {
        guard let vertexFunction = library.makeFunction(name: "vertex_shader"),
              let fragmentFunction = library.makeFunction(name: fragmentFunctionName(for: shaderType)) else {
            throw MetalError.functionCreationFailed
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    private func fragmentFunctionName(for shaderType: ShaderType) -> String {
        switch shaderType {
            case .beautify:
                return "beautify_shader"
            case .dreamy:
                return "dreamy_shader"
            case .vintage:
                return "vintage_shader"
            case .wave:
                return "wave_shader"
        }
    }
    
    func setShaderType(_ type: ShaderType) {
        currentShaderType = type
    }
    
    func render(pixelBuffer: CVPixelBuffer, to drawable: CAMetalDrawable) throws {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let pipelineState = pipelineStates[currentShaderType] else {
            return
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // Update uniforms
        uniforms.time = Float(CACurrentMediaTime() - startTime)
        uniformsBuffer.contents().copyMemory(from: &uniforms, byteCount: MemoryLayout<ShaderUniforms>.size)
        
        // Create texture from pixel buffer
        var cvTexture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(nil,
                                                textureCache,
                                                pixelBuffer,
                                                nil,
                                                .bgra8Unorm,
                                                CVPixelBufferGetWidth(pixelBuffer),
                                                CVPixelBufferGetHeight(pixelBuffer),
                                                0,
                                                &cvTexture)
        
        guard let cvTexture = cvTexture,
              let texture = CVMetalTextureGetTexture(cvTexture) else {
            encoder.endEncoding()
            return
        }
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func renderToTexture(pixelBuffer: CVPixelBuffer, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        guard let pipelineState = pipelineStates[currentShaderType] else {
            return
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            throw MetalError.encoderCreationFailed
        }
        
        // Update uniforms
        uniforms.time = Float(CACurrentMediaTime() - startTime)
        uniformsBuffer.contents().copyMemory(from: &uniforms, byteCount: MemoryLayout<ShaderUniforms>.size)
        
        // Create texture from input pixel buffer
        var cvTexture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(nil,
                                                  textureCache,
                                                  pixelBuffer,
                                                  nil,
                                                  .bgra8Unorm,
                                                  CVPixelBufferGetWidth(pixelBuffer),
                                                  CVPixelBufferGetHeight(pixelBuffer),
                                                  0,
                                                  &cvTexture)
        
        guard let cvTexture = cvTexture,
              let texture = CVMetalTextureGetTexture(cvTexture) else {
            encoder.endEncoding()
            throw MetalError.textureCreationFailed
        }
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
    }
    
    func setIntensity(_ intensity: Float) {
        uniforms.intensity = intensity
    }
}

enum MetalError: Error {
    case deviceNotFound
    case commandQueueCreationFailed
    case libraryCreationFailed
    case functionCreationFailed
    case pipelineCreationFailed
    case bufferCreationFailed
    case textureCreationFailed
    case encoderCreationFailed
    case commandBufferCreationFailed
    case samplerStateFailed
}
