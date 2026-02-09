//
//  AssetLoader.swift
//  iOS AR tracking
//
//  Brief: Preloads heavy assets (e.g. USDZ models) at app startup,
//  so that AR rendering code can reuse them without blocking the main thread.
//

import Foundation
import SceneKit
import Combine

final class AssetLoader: ObservableObject {
    static let shared = AssetLoader()

    @Published private(set) var isLoaded: Bool = false

    /// Template node for model0.usdz (cloned by consumers).
    private(set) var model0TemplateNode: SCNNode?

    private init() {}

    /// Kick off loading of all heavy assets. Safe to call multiple times.
    func loadAllAssets() {
        guard !isLoaded else { return }

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            // Load model0.usdz off the main thread
            if let url = Bundle.main.url(forResource: "model0", withExtension: "usdz"),
               let scene = try? SCNScene(url: url) {
                let node = scene.rootNode.clone()
                node.name = "model0Template"
                // Do not set transform here; consumers decide scale/pose.

                await MainActor.run {
                    self.model0TemplateNode = node
                }
            }

            await MainActor.run {
                self.isLoaded = true
            }
        }
    }
}

