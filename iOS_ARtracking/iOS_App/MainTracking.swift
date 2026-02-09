//
//  MainTracking.swift
//  iOS AR tracking
//
//  Brief: Core tracking and AR session management.
//  Handles AR session updates, marker detection, and coordinate system
//  transformations. Updates marker poses and visualizes axes only.
//

import ARKit
import SceneKit
import UIKit
import CoreImage

/// Singleton: ARSessionDelegate, coordinates marker detection and axis visualization
final class MainTracking: NSObject, ARSessionDelegate, ObservableObject {

    static let shared = MainTracking()
    private override init() {}

    private weak var sceneView: ARSCNView?
    @Published var markerInfos: [MarkerInfo] = []

    /// Serial queue: only one frame is processed at a time; avoids piling up ARFrames.
    private let processingQueue = DispatchQueue(label: "com.iOS_ARtracking.markerProcessing", qos: .userInitiated)
    private let processingLock = NSLock()
    private var isProcessing = false

    func attach(to view: ARSCNView) {
        sceneView = view
        view.session.delegate = self
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard sceneView != nil else { return }
        guard case .normal = frame.camera.trackingState else { return }

        // Drop frame if still processing last one (keeps at most 1 ARFrame in flight)
        processingLock.lock()
        if isProcessing {
            processingLock.unlock()
            return
        }
        isProcessing = true
        processingLock.unlock()

        let capturedImage = frame.capturedImage
        let intrinsics = frame.camera.intrinsics

        processingQueue.async { [weak self] in
            guard let self = self else {
                MainTracking.shared.clearProcessingFlag()
                return
            }

            let markerSize: Float = MarkerDetectionConfig.markerSizeM
            guard let bgraBuffer = MarkerDetection.shared.pixelBufferBGRA(from: capturedImage) else {
                self.clearProcessingFlag()
                return
            }
            let targetWidth = MarkerDetectionConfig.targetWidth
            let targetHeight = MarkerDetectionConfig.targetHeight
            guard let downscaledBuffer = MarkerDetection.shared.resizePixelBuffer(bgraBuffer, width: targetWidth, height: targetHeight) else {
                self.clearProcessingFlag()
                return
            }
            let K = MarkerDetection.shared.adjustCameraIntrinsics(intrinsics, bgraBuffer, targetWidth, targetHeight)

            let poses = OpenCVWrapper.detectMarkers(
                downscaledBuffer,
                intrinsics: K,
                markerSizeM: markerSize
            )

            // Swift 侧不过滤：OpenCVWrapper.mm 内部负责按 enabled id 列表过滤
            let markerInfos = poses.map { pose in
                let id = Int(pose.markerId)
                let raw = Math.opencvToARKit(pose.transform)
                let filtered = Math.filterHomomatrix(raw, markerId: id)
                return MarkerInfo(id: id, homoMat: filtered)
            }

            DispatchQueue.main.async {
                self.markerInfos = markerInfos
                self.clearProcessingFlag()
            }
        }
    }

    private func clearProcessingFlag() {
        processingLock.lock()
        isProcessing = false
        processingLock.unlock()
    }
}
