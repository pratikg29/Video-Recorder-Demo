//
//  MetalTypes.swift
//  VideoEditorDemo
//
//  Created by Pratik Gadhesariya on 05/11/24.
//

import simd
import Metal

struct Vertex {
    let position: SIMD3<Float>
    let textureCoordinate: SIMD2<Float>
    
    static func vertices() -> [Vertex] {
        [
            Vertex(position: SIMD3<Float>(-1, -1, 0), textureCoordinate: SIMD2<Float>(0, 1)),
            Vertex(position: SIMD3<Float>(1, -1, 0), textureCoordinate: SIMD2<Float>(1, 1)),
            Vertex(position: SIMD3<Float>(-1, 1, 0), textureCoordinate: SIMD2<Float>(0, 0)),
            Vertex(position: SIMD3<Float>(1, 1, 0), textureCoordinate: SIMD2<Float>(1, 0))
        ]
    }
}

struct ShaderUniforms {
    var time: Float
    var intensity: Float
}

//enum MetalError: Error {
//    case deviceNotFound
//    case commandQueueCreationFailed
//    case libraryCreationFailed
//    case functionCreationFailed
//    case pipelineCreationFailed
//    case bufferCreationFailed
//    case textureCreationFailed
//}
