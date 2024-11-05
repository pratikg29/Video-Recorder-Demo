//
//  CameraViewModel.swift
//  VideoEditorDemo
//
//  Created by Pratik Gadhesariya on 05/11/24.
//

import SwiftUI
import AVFoundation

@MainActor
class CameraViewModel: ObservableObject {
    @Published var currentFrame: CVPixelBuffer?
    @Published var isRecording = false
    @Published var isFlashOn = false
    @Published var showPreview = false
    @Published var lastRecordingURL: URL?
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var zoomFactor: CGFloat = 1.0
    @Published var isFrontCamera = false
    
    let metalRenderer: MetalRenderer
    private let cameraManager: CameraManager
    
    init() {
        do {
            self.metalRenderer = try MetalRenderer()
            self.cameraManager = CameraManager(metalRenderer: metalRenderer)
            self.cameraManager.delegate = self
        } catch {
            fatalError("Failed to initialize camera: \(error)")
        }
    }
    
    func setupCamera() async {
        do {
            try await cameraManager.requestPermissions()
            try cameraManager.setupCamera()
            cameraManager.startSession()
        } catch {
            await MainActor.run {
                showError = true
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func startRecording() {
        guard !isRecording else { return }
        do {
            try cameraManager.startRecording()
            isRecording = true
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        Task {
            do {
                try await cameraManager.stopRecording()
                isRecording = false
                lastRecordingURL = cameraManager.recordingURL
                showPreview = true
            } catch {
                showError = true
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func toggleFlash() {
        cameraManager.toggleFlash()
        isFlashOn = cameraManager.flashMode == .on
    }
    
    func flipCamera() {
        do {
            try cameraManager.flipCamera()
            isFrontCamera = cameraManager.currentPosition == .front
        } catch {
            showError = true
            errorMessage = "Failed to flip camera: \(error.localizedDescription)"
        }
    }
    
    func handleZoom(scale: CGFloat) {
        let newZoomFactor = zoomFactor * scale
        cameraManager.setZoom(factor: newZoomFactor)
        zoomFactor = cameraManager.currentZoomFactor
    }
    
    func updateShaderIntensity(_ value: Float) {
        metalRenderer.setIntensity(value)
    }
    
    func updateShader(type: ShaderType) {
        metalRenderer.setShaderType(type)
    }
    
    func saveToGallery() async -> Bool {
        do {
            try await cameraManager.saveToGallery()
            return true
        } catch {
            await MainActor.run {
                showError = true
                errorMessage = "Failed to save video: \(error.localizedDescription)"
            }
            return false
        }
    }
}

extension CameraViewModel: CameraManagerDelegate {
    func cameraManager(_ manager: CameraManager, didOutput pixelBuffer: CVPixelBuffer) {
        Task { @MainActor in
            currentFrame = pixelBuffer
        }
    }
}
