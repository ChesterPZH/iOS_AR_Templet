//
//  VisualPose.swift
//  iOS AR tracking
//
//  Brief: Subscribes to MainTracking.markerInfos off the main thread
//  and updates marker pose axes (X/Y/Z) on the main thread.
//

import Foundation
import SceneKit
import simd
import ARKit
import Combine

final class VisualPose: ObservableObject {
    static let shared = VisualPose()

    private weak var sceneView: ARSCNView?

    private let processingQueue = DispatchQueue(label: "com.iOS_ARtracking.visualPose", qos: .userInitiated)
    private var markerInfosCancellable: AnyCancellable?

    private init() {
        markerInfosCancellable = MainTracking.shared.$markerInfos
            .receive(on: processingQueue)
            .sink { [weak self] infos in
                self?.process(markerInfos: infos)
            }
    }

    func attachSceneView(_ view: ARSCNView) {
        self.sceneView = view
    }

    /// 后台消费 markerInfos，主线程更新 pose 坐标轴
    private func process(markerInfos: [MarkerInfo], axisLength: Float = 0.02) {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let sceneView = self.sceneView,
                  let cameraNode = sceneView.pointOfView else { return }

            // 清理旧的轴
            cameraNode.childNodes
                .filter { $0.name == "markerAxis" }
                .forEach { $0.removeFromParentNode() }

            // 没有 marker，直接返回
            guard !markerInfos.isEmpty else { return }

            // 为每个 marker 画轴
            for marker in markerInfos {
                let axisNode = VisualPose.makeAxisNode(length: axisLength)
                axisNode.name = "markerAxis"
                axisNode.simdTransform = marker.homoMat
                cameraNode.addChildNode(axisNode)
            }
        }
    }

    private static func makeAxisNode(length: Float) -> SCNNode {
        let scale: Float = 0.5
        func line(color: UIColor, axis: SIMD3<Float>) -> SCNNode {
            let cyl = SCNCylinder(radius: CGFloat(length * 0.05 * scale),
                                  height: CGFloat(length * scale))
            cyl.firstMaterial?.diffuse.contents = color
            let node = SCNNode(geometry: cyl)
            node.position = SCNVector3(axis * (length * scale / 2))
            if axis.x == 1 { node.eulerAngles.z = .pi/2 }
            if axis.y == 1 { }
            if axis.z == 1 { node.eulerAngles.x = .pi/2 }
            return node
        }
        let root = SCNNode()
        root.addChildNode(line(color: .red,   axis: [1,0,0]))
        root.addChildNode(line(color: .green, axis: [0,1,0]))
        root.addChildNode(line(color: .blue,  axis: [0,0,1]))
        return root
    }
}
