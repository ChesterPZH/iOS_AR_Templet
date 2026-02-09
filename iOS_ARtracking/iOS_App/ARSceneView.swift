//
//  ARSceneView.swift
//  iOS AR tracking
//
//  Brief: AR scene view setup and session configuration.
//

import Foundation
import ARKit
import SceneKit

@MainActor
class ARSceneView: ObservableObject {
    static let shared = ARSceneView()
    let sceneView: ARSCNView

    private init() {
        sceneView = ARSCNView()
        sceneView.automaticallyUpdatesLighting = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.scene.lightingEnvironment.intensity = 1.5

        let cfg = ARWorldTrackingConfiguration()
        sceneView.session.run(cfg)

        MainTracking.shared.attach(to: sceneView)
        VisualPose.shared.attachSceneView(sceneView)
        Marker0.shared.attachSceneView(sceneView)
    }
}
