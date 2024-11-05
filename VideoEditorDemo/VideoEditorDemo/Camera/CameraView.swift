//
//  CameraView.swift
//  VideoEditorDemo
//
//  Created by Pratik Gadhesariya on 05/11/24.
//

import SwiftUI
import AVFoundation
import Photos

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @State private var showingGallerySuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var sliderValue: Float = 1.0
    @StateObject private var shaderSettings = ShaderSettings()
    @State private var showingShaderSelector = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if let pixelBuffer = viewModel.currentFrame {
                    MetalView(metalRenderer: viewModel.metalRenderer,
                             pixelBuffer: pixelBuffer)
                    .edgesIgnoringSafeArea(.all)
                }
                
                // Controls overlay
                VStack {
                    // Top controls
                    HStack {
                        Button(action: viewModel.toggleFlash) {
                            Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .padding()
                        }
                        
                        Spacer()
                        
                        Button(action: viewModel.flipCamera) {
                            Image(systemName: "camera.rotate.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .padding()
                                .rotationEffect(.degrees(viewModel.isFrontCamera ? 180 : 0))
                                .animation(.spring(), value: viewModel.isFrontCamera)
                        }
                    }
                    .padding(.horizontal)
                    .background(LinearGradient(colors: [.black.opacity(0.3), .clear],
                                               startPoint: .top,
                                               endPoint: .bottom))
                    
                    Spacer()
                    
                    // Effect intensity slider
                    VStack {
                        Text("Effect Intensity")
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                        
                        Slider(value: $sliderValue, in: 0...2) { _ in
                            viewModel.updateShaderIntensity(sliderValue)
                        }
                        .padding(.horizontal, 40)
                    }
                    .padding()
                    
                    
                    // Bottom controls
                    VStack(spacing: 20) {
                        // Current shader indicator
                        Button(action: { showingShaderSelector = true }) {
                            HStack {
                                Image(systemName: shaderSettings.currentShader.icon)
                                Text(shaderSettings.currentShader.rawValue)
                                Image(systemName: "chevron.up")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(shaderSettings.currentShader.color.opacity(0.3))
                                    .overlay(
                                        Capsule()
                                            .stroke(shaderSettings.currentShader.color, lineWidth: 1)
                                    )
                            )
                        }
                        
                        HStack(spacing: 30) {
                            Spacer()
                            
                            Button(action: {
                                viewModel.isRecording ? viewModel.stopRecording() : viewModel.startRecording()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 72, height: 72)
                                    
                                    if viewModel.isRecording {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.red)
                                            .frame(width: 32, height: 32)
                                    } else {
                                        Circle()
                                            .stroke(Color.red, lineWidth: 4)
                                            .frame(width: 60, height: 60)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(.bottom, 30)
                    .background(LinearGradient(colors: [.clear, .black.opacity(0.3)],
                                               startPoint: .top,
                                               endPoint: .bottom))
                    
                    
                    // Bottom controls
//                    HStack(spacing: 30) {
//                        Spacer()
//                        
//                        // Record button
//                        Button(action: {
//                            viewModel.isRecording ? viewModel.stopRecording() : viewModel.startRecording()
//                        }) {
//                            ZStack {
//                                Circle()
//                                    .fill(Color.white)
//                                    .frame(width: 72, height: 72)
//                                
//                                if viewModel.isRecording {
//                                    RoundedRectangle(cornerRadius: 4)
//                                        .fill(Color.red)
//                                        .frame(width: 32, height: 32)
//                                } else {
//                                    Circle()
//                                        .stroke(Color.red, lineWidth: 4)
//                                        .frame(width: 60, height: 60)
//                                }
//                            }
//                        }
//                        
//                        Spacer()
//                    }
//                    .padding(.bottom, 30)
                }
            }
            .onAppear {
                Task {
                    try? await viewModel.setupCamera()
                }
            }
        }
        .alert("Success", isPresented: $showingGallerySuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Video saved to gallery successfully!")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $viewModel.showPreview) {
            if let url = viewModel.lastRecordingURL {
                VideoPreviewView(videoURL: url) { success in
                    if success {
                        showingGallerySuccess = true
                    } else {
                        errorMessage = "Failed to save video to gallery"
                        showingError = true
                    }
                }
            }
        }
        .onChange(of: shaderSettings.currentShader) { newShader in
            viewModel.updateShader(type: newShader)
        }
        .onChange(of: shaderSettings.intensity) { newValue in
            viewModel.updateShaderIntensity(newValue)
        }
        .sheet(isPresented: $showingShaderSelector) {
            ShaderSelectorView(settings: shaderSettings)
        }
        .onAppear {
            // Set initial shader
            viewModel.updateShader(type: shaderSettings.currentShader)
            viewModel.updateShaderIntensity(shaderSettings.intensity)
        }
    }
}
