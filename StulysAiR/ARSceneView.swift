//
//  ARSceneView.swift
//  EE267 Project
//
//  Concluded by Chester Pan on 6/3/25
//
//  Brief: Manages AR scene view and initialization.
//  This class handles the setup and configuration of the AR scene view,
//  including session configuration and interaction setup.
//

import Foundation
import ARKit
import SceneKit

@MainActor
class ARSceneView: ObservableObject {
    static let shared = ARSceneView()
    let sceneView: ARSCNView  // Main AR scene view

    private init() {
        // Initialize AR scene view
        sceneView = ARSCNView()
        sceneView.automaticallyUpdatesLighting = true
        
        // Configure AR session
        let cfg = ARWorldTrackingConfiguration()
        sceneView.session.run(cfg)
        
        // Initialize managers
        MainTracking.shared.attach(to: sceneView)
        VisualContent.shared.attachSceneView(sceneView)
        
        // Set up Apple Pencil interaction
        if #available(iOS 17.5, *) {
            let interaction = UIPencilInteraction()
            interaction.delegate = PencilManager.shared
            sceneView.addInteraction(interaction)
        }
    }
} 
