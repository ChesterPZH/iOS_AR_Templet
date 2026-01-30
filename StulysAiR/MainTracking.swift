//
//  MainTracking.swift
//  EE267 Project
//
//  Concluded by Chester Pan on 6/3/25
//
//  Brief: Core tracking and AR session management.
//  This class handles AR session updates, marker detection, and coordinate system
//  transformations. It serves as the main coordinator between different components.
//

import ARKit
import SceneKit
import UIKit
import CoreImage

/// Singleton: Both ARSessionDelegate and SceneKit manager
final class MainTracking: NSObject, ARSessionDelegate, ObservableObject {

    static let shared = MainTracking()
    private override init() {}

    private weak var sceneView: ARSCNView?  // Reference to AR scene view
    @Published var markerInfos: [MarkerInfo] = []  // Current marker tracking results
    private var lastTipFiltered: simd_float3? = nil  // Last valid tip position

    // ---------- Public Interface ----------
    // Attach to AR scene view and set up session
    func attach(to view: ARSCNView) {
        sceneView = view
        view.session.delegate = self
    }

    // ---------- Session Callbacks ----------
    // Handle AR session frame updates
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let view = sceneView else { return }
        guard case .normal = frame.camera.trackingState else { return }

        // Process frame in background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Marker detection parameters
            let markerSize: Float = 0.019  // 19mm marker size
            
            // Get and process camera image
            guard let bgraBuffer = MarkerDetection.shared.pixelBufferBGRA(from: frame.capturedImage) else { return }
            let targetWidth = 480
            let targetHeight = 270
            guard let downscaledBuffer = MarkerDetection.shared.resizePixelBuffer(bgraBuffer, width: targetWidth, height: targetHeight) else { return }
            let K = MarkerDetection.shared.adjustCameraIntrinsics(frame.camera.intrinsics, bgraBuffer, targetWidth, targetHeight)

            // Detect markers using OpenCV
            let poses = OpenCVWrapper.detectMarkers(
                downscaledBuffer,
                intrinsics: K,
                markerSizeM: markerSize
            )
            
            // Clean up tracking state for disappeared markers
            let currentMarkerIds = Set(poses.map { Int($0.markerId) })
            let previousMarkerIds = Set(markerInfos.map { $0.id })
            let disappearedMarkerIds = previousMarkerIds.subtracting(currentMarkerIds)
            for id in disappearedMarkerIds {
                Math.clearMarkerState(markerId: id)
            }
            
            // Process detected markers
            let markerInfos = poses.map {
                let t = Math.opencvToARKit($0.transform)  // Convert to ARKit coordinate system
                let filteredT = Math.filterHomomatrix(t, markerId: Int($0.markerId))  // Apply filtering
                return MarkerInfo(id: Int($0.markerId), homoMat: filteredT)
            }
            
            // Calculate average tip position
            let avgMatrix = VirtualPencilModel.shared.calculateAverageTip(markerInfos: markerInfos)
            
            // Process tip position with filtering
            var tipFiltered: simd_float3? = nil
            var tipVec: simd_float3? = nil
            if let avgMatrix = avgMatrix {
                tipVec = Math.homoMatToTipVec(avgMatrix)
            }
            if let tipVec = tipVec {
                let smoothed = Math.smoothTipVec(tipVec)  // Apply smoothing
                let oneEuroFiltered = Math.oneEuroFilter(smoothed, minCutoff: 2.0, beta: 0.5, dCutoff: 2.0)  // Apply OneEuro filter
                tipFiltered = Math.jumpFilter(oneEuroFiltered)  // Apply jump filtering
            }

            // Update UI in main thread
            DispatchQueue.main.async {
                self.markerInfos = markerInfos
                if markerInfos.isEmpty {
                    // No markers detected
                    VisualContent.shared.renderTip(nil)
                    VisualContent.shared.drawAxesForMarkers(markerInfos: [])
                    // Use last valid tip position
                    if let lastTip = self.lastTipFiltered {
                        StrokeManager.shared.updateTip(lastTip, in: frame.camera.transform)
                    }
                } else {
                    // Update visualizations and stroke
                    VisualContent.shared.renderTip(tipFiltered)
                    VisualContent.shared.drawAxesForMarkers(markerInfos: markerInfos)
                    StrokeManager.shared.updateTip(tipFiltered, in: frame.camera.transform)
                    // Update last valid tip position
                    self.lastTipFiltered = tipFiltered
                }
            }
        }
    }
} 
