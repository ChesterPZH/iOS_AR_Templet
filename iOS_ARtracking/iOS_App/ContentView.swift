//
//  ContentView.swift
//  iOS AR tracking
//
//  Brief: Main SwiftUI view. AR view only; marker pose axes are drawn by VisualPose.
//

import SwiftUI
import ARKit

struct ARViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARSCNView {
        ARSceneView.shared.sceneView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) { }
}

struct ContentView: View {
    @StateObject private var assetLoader = AssetLoader.shared

    var body: some View {
        Group {
            if assetLoader.isLoaded {
                ARViewContainer()
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        MainTracking.shared.attach(to: ARSceneView.shared.sceneView)
                        VisualPose.shared.attachSceneView(ARSceneView.shared.sceneView)
                        Marker0.shared.attachSceneView(ARSceneView.shared.sceneView)
                    }
            } else {
                // 黑屏 + loading
                Color.black
                    .ignoresSafeArea()
                    .overlay(
                        ProgressView("Loading...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .foregroundColor(.white)
                    )
                    .onAppear {
                        assetLoader.loadAllAssets()
                    }
            }
        }
    }
}
