//
//  ShaderSelectorView.swift
//  VideoEditorDemo
//
//  Created by Pratik Gadhesariya on 05/11/24.
//

import SwiftUI

struct ShaderSelectorView: View {
    @ObservedObject var settings: ShaderSettings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Select Effect")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(ShaderType.allCases, id: \.self) { shader in
                                ShaderPreviewCard(
                                    shader: shader,
                                    isSelected: settings.currentShader == shader,
                                    action: {
                                        withAnimation {
                                            settings.currentShader = shader
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
//                    VStack(alignment: .leading, spacing: 10) {
//                        Text("Effect Intensity")
//                            .foregroundColor(.white)
//                            .font(.headline)
//                        
//                        HStack {
//                            Image(systemName: "sun.min")
//                                .foregroundColor(.white)
//                            
//                            Slider(value: $settings.intensity, in: 0...1)
//                                .accentColor(settings.currentShader.color)
//                            
//                            Image(systemName: "sun.max")
//                                .foregroundColor(.white)
//                        }
//                    }
//                    .padding()
//                    .background(Color.white.opacity(0.1))
//                    .cornerRadius(15)
//                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

struct ShaderPreviewCard: View {
    let shader: ShaderType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Circle()
                    .fill(shader.color.opacity(0.3))
                    .overlay(
                        Image(systemName: shader.icon)
                            .font(.system(size: 30))
                            .foregroundColor(shader.color)
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(shader.color, lineWidth: isSelected ? 3 : 0)
                    )
                
                Text(shader.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(shader.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .frame(width: 120)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white.opacity(0.1))
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)
        }
    }
}
