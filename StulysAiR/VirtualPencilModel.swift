//
//  VirtualPencilModel.swift
//  EE267 Project
//
//  Concluded by Chester Pan on 6/3/25
//
//  Brief: Manages virtual pencil model and tip position calculation.
//  This class handles the geometric model of the physical pencil and calculates
//  the virtual tip position based on marker tracking data.
//

import Foundation
import SceneKit
import simd
import ARKit

@MainActor
class VirtualPencilModel: ObservableObject {
    static let shared = VirtualPencilModel()

    // ───────────────── Pre-calculated displacement table ─────────────────
    // Calculated with a=10.7 mm, b=17 mm, c=118 mm (45°)
    // √½ ≈ 0.70710678
    private let k: Float = 0.116 * 0.70710678   // 118 mm × sqrt(1/2) ≈ 0.0834386
    private let aZ: Float = -0.0127             // Segment a −Z 10.7 mm
    private let bX: Float = -0.0190             // Segment b −X 17 mm
    private let bZTop: Float = -0.0190          // Top surface segment b −Z 17 mm

    // Lookup table for marker ID to local tip position
    private let vTable: [Int: simd_float3]

    private init() {
        // Initialize lookup table with pre-calculated positions
        vTable = [
            2: [ bX,  +k,  k + aZ ],  // Marker 2 position
            3: [ bX,  +k, -k + aZ ],  // Marker 3 position
            4: [ bX,  -k, -k + aZ ],  // Marker 4 position
            5: [ bX,  -k,  k + aZ ],  // Marker 5 position
            6: [ +k,  +k,  bZTop + aZ ]  // Marker 6 position
        ]
    }

    /// Calculate average tip position from multiple marker poses
    func calculateAverageTip(markerInfos: [MarkerInfo]) -> simd_float4x4? {
        // Group markers by ID
        let grouped = Dictionary(grouping: markerInfos, by: { $0.id })
        
        // Process each group of markers
        for (id, infos) in grouped {
            let transforms = infos.map { $0.homoMat }
            guard let vLocal = vTable[id], !transforms.isEmpty else { continue }
            
            // Calculate tip position for each marker
            let tips: [simd_float3] = transforms.map { T in
                let tip = (T * simd_float4(vLocal, 1)).xyz
                return tip
            }
            
            // Calculate average tip position
            let avg = tips.reduce(simd_float3.zero, +) / Float(tips.count)
            
            // Create transform matrix from average position
            let avgMatrix = simd_float4x4(
                SIMD4<Float>(1, 0, 0, 0),
                SIMD4<Float>(0, 1, 0, 0),
                SIMD4<Float>(0, 0, 1, 0),
                SIMD4<Float>(avg.x, avg.y, avg.z, 1)
            )
            return avgMatrix
        }
        return nil
    }
}