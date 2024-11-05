//
//  ShaderType.swift
//  VideoEditorDemo
//
//  Created by Pratik Gadhesariya on 05/11/24.
//

import SwiftUI

enum ShaderType: String, CaseIterable {
    case beautify = "Beautify"
    case dreamy = "Dreamy"
    case vintage = "Vintage"
    case wave = "Wave"
    
    var description: String {
        switch self {
            case .beautify:
                return "Smooth skin enhancement with warm glow"
            case .dreamy:
                return "Soft dreamy effect with subtle highlights"
            case .vintage:
                return "Classic film look with grain effect"
            case .wave:
                return "Wave effect"
        }
    }
    
    var icon: String {
        switch self {
            case .beautify:
                return "sparkles"
            case .dreamy:
                return "cloud.sun"
            case .vintage:
                return "camera.filters"
            case .wave:
                return "water.waves"
        }
    }
    
    var color: Color {
        switch self {
            case .beautify:
                return .pink
            case .dreamy:
                return .purple
            case .vintage:
                return .orange
            case .wave:
                return .blue
        }
    }
}

class ShaderSettings: ObservableObject {
    @Published var currentShader: ShaderType = .beautify
    @Published var intensity: Float = 0.5
}
