//
//  VisualContent.swift
//  EE267 Project
//
//  Concluded by Chester Pan on 6/3/25
//
//  Brief: Manages visual feedback and debugging visualization in AR.
//  This class handles the rendering of visual elements such as the pencil tip,
//  coordinate axes for markers, and other debugging visualizations.
//

import Foundation
import SceneKit
import simd
import ARKit

@MainActor
class VisualContent: ObservableObject {
    static let shared = VisualContent()
    private var pencilNode: SCNNode?      // Node for pencil visualization
    private var eraserNode: SCNNode?      // Node for eraser visualization
    private weak var sceneView: ARSCNView? // Reference to AR scene view
    private var tipNode: SCNNode?         // Node for tip visualization

    // Attach AR scene view
    func attachSceneView(_ view: ARSCNView) {
        self.sceneView = view
    }

    // Render pencil tip visualization
    func renderTip(_ tip: simd_float3?) {
        // Remove old tip visualization
        tipNode?.removeFromParentNode()
        
        guard let tip = tip,
              let sceneView = sceneView,
              let cameraNode = sceneView.pointOfView else { return }
        
        // Create new tip visualization
        let sphere = SCNSphere(radius: CGFloat(StrokeManager.shared.strokeRadius * 2))  // 2x radius for visibility
        
        // Select color based on current mode
        let color = PencilManager.shared.switchOne ? 
            StrokeManager.shared.rulerColor : 
            StrokeManager.shared.strokeColor
        
        sphere.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.9)  // 90% opacity
        
        let node = SCNNode(geometry: sphere)
        node.simdPosition = tip
        
        // Add to camera node for consistent visibility
        cameraNode.addChildNode(node)
        tipNode = node
    }

    /// Draw coordinate axes for each marker for debugging
    func drawAxesForMarkers(markerInfos: [MarkerInfo], axisLength: Float = 0.02) {
        guard let sceneView = sceneView else { return }
        if let cameraNode = sceneView.pointOfView {
            // Remove old axis visualizations
            cameraNode.childNodes.filter { $0.name == "markerAxis" }.forEach { $0.removeFromParentNode() }
            
            // Create new axis visualizations for each marker
            for marker in markerInfos {
                let mat = marker.homoMat
                let axisNode = VisualContent.makeAxisNode(length: axisLength)
                axisNode.name = "markerAxis"
                axisNode.simdTransform = mat
                cameraNode.addChildNode(axisNode)
            }
        }
    }

    /// Generate visualization node for three coordinate axes
    private static func makeAxisNode(length: Float) -> SCNNode {
        let scale: Float = 0.5
        // Create a cylinder for each axis
        func line(color: UIColor, axis: SIMD3<Float>) -> SCNNode {
            let cyl = SCNCylinder(radius: CGFloat(length * 0.05 * scale),
                                  height: CGFloat(length * scale))
            cyl.firstMaterial?.diffuse.contents = color
            let node = SCNNode(geometry: cyl)
            node.position = SCNVector3(axis * (length * scale / 2))
            // Rotate cylinder to align with axis
            if axis.x == 1 { node.eulerAngles.z = .pi/2 }
            if axis.y == 1 { /* default orientation */ }
            if axis.z == 1 { node.eulerAngles.x = .pi/2 }
            return node
        }
        
        // Create root node with three colored axes
        let root = SCNNode()
        root.addChildNode(line(color: .red,   axis: [1,0,0]))  // X axis
        root.addChildNode(line(color: .green, axis: [0,1,0]))  // Y axis
        root.addChildNode(line(color: .blue,  axis: [0,0,1]))  // Z axis
        return root
    }
}