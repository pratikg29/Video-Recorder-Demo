//
//  VideoPreviewView.swift
//  VideoEditorDemo
//
//  Created by Pratik Gadhesariya on 05/11/24.
//

import SwiftUI
import AVKit
import Photos

struct VideoPreviewView: View {
    let videoURL: URL
    let onSave: (Bool) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = VideoPreviewViewModel()
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    if let player = viewModel.player {
                        AVPlayerControllerRepresentable(player: player)
                            .ignoresSafeArea()
                    }
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                    
                    if viewModel.showError {
                        VStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.yellow)
                            Text(viewModel.errorMessage)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding()
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Discard") {
                        viewModel.cleanup()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.saveToGallery()
                            dismiss()
                            onSave(viewModel.savedSuccessfully)
                        }
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            viewModel.setupPlayer(with: videoURL)
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
}

struct AVPlayerControllerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspectFill
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

class VideoPreviewViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var savedSuccessfully = false
    
    private var videoURL: URL?
    private var timeObserver: Any?
    
    func setupPlayer(with url: URL) {
        isLoading = true
        showError = false
        videoURL = url
        
        do {
            // Check if the file exists
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Video file not found"])
            }
            
            // Check file size
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let fileSize = attributes[.size] as? Int64, fileSize > 0 else {
                throw NSError(domain: "", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid video file size"])
            }
            
            let asset = AVAsset(url: url)
            let playerItem = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: playerItem)
            
            // Add time observer to track playback status
            timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: .main) { [weak self] _ in
                if let currentItem = player.currentItem {
                    if currentItem.status == .failed {
                        self?.handlePlaybackError(currentItem.error)
                    }
                }
            }
            
            self.player = player
            player.play()
            
        } catch {
            handlePlaybackError(error)
        }
        
        isLoading = false
    }
    
    func saveToGallery() async {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = true
            self?.showError = false
            self?.savedSuccessfully = false
        }
        
        do {
            guard let videoURL else { return }
            try await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            }
            
            await MainActor.run {
                savedSuccessfully = true
                isLoading = false
            }
            
        } catch {
            await MainActor.run {
                showError = true
                errorMessage = "Failed to save video: \(error.localizedDescription)"
                isLoading = false
                savedSuccessfully = false
            }
        }
    }
    
    private func handlePlaybackError(_ error: Error?) {
        showError = true
        errorMessage = error?.localizedDescription ?? "Failed to play video"
        isLoading = false
    }
    
    func cleanup() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        player?.pause()
        player = nil
    }
}
