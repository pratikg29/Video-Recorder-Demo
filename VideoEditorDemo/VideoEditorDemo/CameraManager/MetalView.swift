//
//  MetalView.swift
//  VideoEditorDemo
//
//  Created by Pratik Gadhesariya on 05/11/24.
//

import SwiftUI
import MetalKit
import AVFoundation

struct MetalView: UIViewRepresentable {
    let metalRenderer: MetalRenderer
    let pixelBuffer: CVPixelBuffer
    
    class Coordinator: NSObject, MTKViewDelegate {
        var parent: MetalView
        var currentPixelBuffer: CVPixelBuffer?
        
        init(_ parent: MetalView) {
            self.parent = parent
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        
        func draw(in view: MTKView) {
            guard let currentDrawable = view.currentDrawable,
                  let pixelBuffer = currentPixelBuffer else {
                return
            }
            
            do {
                try parent.metalRenderer.render(pixelBuffer: pixelBuffer, to: currentDrawable)
            } catch {
                print("Rendering error: \(error)")
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.framebufferOnly = false
        mtkView.enableSetNeedsDisplay = true
        mtkView.preferredFramesPerSecond = 60
        mtkView.colorPixelFormat = .bgra8Unorm
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.currentPixelBuffer = pixelBuffer
        uiView.setNeedsDisplay()
    }
}
