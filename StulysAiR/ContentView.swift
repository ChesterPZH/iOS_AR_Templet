//
//  ContentView.swift
//  EE267 Project
//
//  Concluded by Chester Pan on 6/3/25
//
//  Brief: Main SwiftUI view for the AR drawing application.
//  This file defines the user interface including the AR view container,
//  control panel for drawing settings, and mode indicators.
//

import SwiftUI
import ARKit

// UIViewRepresentable wrapper for ARSCNView
struct ARViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARSCNView {
        ARSceneView.shared.sceneView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) { }
}

// Main view structure
struct ContentView: View {
    // State objects for managers
    @StateObject private var pencilManager = PencilManager.shared
    @StateObject private var strokeManager = StrokeManager.shared
    
    // Drawing settings
    @State private var strokeRadius: Float = 0.001  // Default stroke radius
    @State private var selectedColor: UIColor = .yellow  // Default stroke color
    @State private var rulerColor: UIColor = .red  // Default ruler color
    
    // Available colors with emoji indicators
    private let colors: [(UIColor, String)] = [
        (.red, "🟥"),
        (.yellow, "🟨"),
        (.green, "🟩"),
        (.blue, "🟦"),
        (.purple, "🟪"),
        (.black, "⬛️"),
        (.white, "⬜️")
    ]
    
    var body: some View {
        ZStack {
            // AR view container
            ARViewContainer()
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    // Initialize managers
                    MainTracking.shared.attach(to: ARSceneView.shared.sceneView)
                    VisualContent.shared.attachSceneView(ARSceneView.shared.sceneView)
                    StrokeManager.shared.attachSceneView(ARSceneView.shared.sceneView)
                }
            
            // Mode indicator at top
            VStack {
                HStack {
                    Spacer()
                    Text(pencilManager.switchOne ? "📏 Ruler" : "✏️ Regular")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                    Spacer()
                }
                .padding(.top, 50)
                
                Spacer()
            }
            
            // Control panel at bottom
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        // Stroke color picker
                        HStack(spacing: 5) {
                            Text("Tip:")
                                .font(.caption)
                                .foregroundColor(.white)
                            ForEach(colors, id: \.1) { color, emoji in
                                Button(action: {
                                    selectedColor = color
                                }) {
                                    Text(emoji)
                                        .font(.caption)
                                        .padding(3)
                                        .background(selectedColor == color ? Color.gray.opacity(0.3) : Color.clear)
                                        .cornerRadius(3)
                                }
                            }
                        }
                        
                        // Ruler color picker
                        HStack(spacing: 5) {
                            Text("Ruler:")
                                .font(.caption)
                                .foregroundColor(.white)
                            ForEach(colors, id: \.1) { color, emoji in
                                Button(action: {
                                    rulerColor = color
                                }) {
                                    Text(emoji)
                                        .font(.caption)
                                        .padding(3)
                                        .background(rulerColor == color ? Color.gray.opacity(0.3) : Color.clear)
                                        .cornerRadius(3)
                                }
                            }
                        }
                        
                        // Stroke radius adjustment
                        HStack {
                            Text("R: \(String(format: "%.1f", strokeRadius * 1000))mm")
                                .font(.caption)
                                .foregroundColor(.white)
                            Slider(value: $strokeRadius, in: 0.0005...0.005, step: 0.0005)
                                .frame(width: 100)
                        }
                        
                        // Clear button
                        Button(action: {
                            strokeManager.clearAll()
                        }) {
                            Text("Clear")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.7))
                                .cornerRadius(5)
                        }
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                    
                    Spacer()
                }
                .padding(.leading, 20)
                .padding(.bottom, 20)
            }
        }
        // Update stroke settings when changed
        .onChange(of: strokeRadius) { newValue in
            strokeManager.updateStrokeRadius(newValue)
        }
        .onChange(of: selectedColor) { newValue in
            strokeManager.updateStrokeColor(newValue)
        }
        .onChange(of: rulerColor) { newValue in
            strokeManager.updateRulerColor(newValue)
        }
    }
}

