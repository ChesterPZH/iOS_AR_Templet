//
//  StrokeManager.swift
//  EE267 Project
//
//  Concluded by Chester Pan on 6/3/25
//
//  Brief: Manages stroke rendering and ruler functionality in AR.
//  This class handles the creation, rendering, and management of strokes in 3D space,
//  including both freehand drawing and ruler-assisted straight lines.
//

import Foundation
import SceneKit
import simd
import ARKit

// Structure to store stroke point information
struct StrokePoint {
    let position: simd_float3  // 3D position in world space
    let node: SCNNode         // SceneKit node for visualization
}

@MainActor
class StrokeManager: ObservableObject {
    static let shared = StrokeManager()
    
    private var strokes: [StrokePoint] = []  // Array of all stroke points
    private weak var sceneView: ARSCNView?   // Reference to AR scene view
    
    // Configuration parameters
    var strokeRadius: Float = 0.001  // Default stroke radius (2mm)
    private var rulerRadius: Float = 0.001   // Default ruler line radius (2mm)
    var strokeColor: UIColor = .yellow       // Default stroke color
    var rulerColor: UIColor = .red           // Default ruler line color
    
    // Ruler mode state
    private var rulerStartPoint: simd_float3?  // Starting point for ruler line
    private var previewNode: SCNNode?          // Preview line node
    
    // Attach AR scene view
    func attachSceneView(_ view: ARSCNView) {
        self.sceneView = view
    }
    
    // Update pencil tip position and handle drawing
    func updateTip(_ tip: simd_float3?, in worldTransform: simd_float4x4) {
        guard let tip = tip else { return }
        
        if PencilManager.shared.switchOne {
            // Ruler mode
            if PencilManager.shared.switchTwo {
                // Draw straight line
                handleRulerMode(tip, in: worldTransform)
            } else {
                // End line drawing
                endRulerMode()
            }
        } else {
            // Normal drawing mode
            if PencilManager.shared.switchTwo {
                // Only draw when switchTwo is enabled
                addPoint(tip, in: worldTransform)
            }
        }
    }
    
    // Update stroke radius
    func updateStrokeRadius(_ radius: Float) {
        strokeRadius = radius
    }
    
    // Update stroke color
    func updateStrokeColor(_ color: UIColor) {
        strokeColor = color
    }
    
    // Update ruler line color
    func updateRulerColor(_ color: UIColor) {
        rulerColor = color
    }
    
    // Add a new stroke point
    private func addPoint(_ point: simd_float3, in worldTransform: simd_float4x4) {
        let worldPoint = (worldTransform * simd_float4(point, 1)).xyz
        
        // Create sphere node for stroke point
        let sphere = SCNSphere(radius: CGFloat(strokeRadius))
        sphere.firstMaterial?.diffuse.contents = strokeColor
        
        let node = SCNNode(geometry: sphere)
        node.simdPosition = worldPoint
        
        // Add to scene
        sceneView?.scene.rootNode.addChildNode(node)
        
        // Save point information
        let strokePoint = StrokePoint(position: worldPoint, node: node)
        strokes.append(strokePoint)
    }
    
    // Handle ruler mode drawing
    private func handleRulerMode(_ point: simd_float3, in worldTransform: simd_float4x4) {
        let worldPoint = (worldTransform * simd_float4(point, 1)).xyz
        
        if rulerStartPoint == nil {
            // Start new ruler measurement
            rulerStartPoint = worldPoint
        } else {
            // Update preview line
            updateRulerPreview(from: rulerStartPoint!, to: worldPoint)
        }
    }
    
    // Update ruler preview line
    private func updateRulerPreview(from start: simd_float3, to end: simd_float3) {
        // Remove old preview
        previewNode?.removeFromParentNode()
        
        // Create new preview line
        let distance = Math.distance(start, end)
        let cylinder = SCNCylinder(radius: CGFloat(rulerRadius), height: CGFloat(distance))
        cylinder.firstMaterial?.diffuse.contents = rulerColor.withAlphaComponent(0.5)
        
        let node = SCNNode(geometry: cylinder)
        
        // Calculate direction vector
        let direction = normalize(end - start)
        
        // Set position to midpoint
        node.simdPosition = (start + end) / 2
        
        // Calculate rotation to align cylinder with direction
        let defaultDirection = simd_float3(0, 1, 0)  // Default cylinder direction
        let rotationAxis = cross(defaultDirection, direction)
        let rotationAngle = acos(dot(defaultDirection, direction))
        
        // Apply rotation
        let rotation = simd_quaternion(rotationAngle, rotationAxis)
        node.simdOrientation = rotation
        
        // Add to scene
        sceneView?.scene.rootNode.addChildNode(node)
        previewNode = node
    }
    
    // End ruler mode and create final line
    private func endRulerMode() {
        if let preview = previewNode {
            // Create final line
            let finalNode = preview.clone()
            finalNode.geometry?.firstMaterial?.diffuse.contents = rulerColor
            
            // Add to scene
            sceneView?.scene.rootNode.addChildNode(finalNode)
            strokes.append(StrokePoint(position: finalNode.simdPosition, node: finalNode))
            
            // Remove preview
            preview.removeFromParentNode()
        }
        
        // Reset state
        rulerStartPoint = nil
        previewNode = nil
    }
    
    // Clear all strokes
    func clearAll() {
        Task { @MainActor in
            // Remove all nodes
            for stroke in strokes {
                stroke.node.removeFromParentNode()
            }
            // Clear array
            strokes.removeAll()
            // Reset ruler mode
            rulerStartPoint = nil
            previewNode?.removeFromParentNode()
            previewNode = nil
            // Force UI update
            objectWillChange.send()
        }
    }
} 