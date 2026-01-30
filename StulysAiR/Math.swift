//
//  Math.swift
//  EE267 Project
//
//  Concluded by Chester Pan on 6/3/25
//
//  Brief: Mathematical utilities and filtering algorithms.
//  This file contains coordinate system transformations, filtering algorithms,
//  and other mathematical utilities used throughout the application.
//

import simd
import ARKit

struct Math {
    // Convert OpenCV coordinate system to ARKit coordinate system
    static func opencvToARKit(_ mat: simd_float4x4) -> simd_float4x4 {
        let cv2ARKit = simd_float4x4(
            SIMD4<Float>( 1,  0,  0, 0),
            SIMD4<Float>( 0, -1,  0, 0),
            SIMD4<Float>( 0,  0, -1, 0),
            SIMD4<Float>( 0,  0,  0, 1)
        )
        return cv2ARKit * mat
    }

    // Transform from camera to world coordinate system
    static func cameraToWorld(cameraTransform: simd_float4x4, markerTransform: simd_float4x4) -> simd_float4x4 {
        // World = World to Camera * Camera to Marker
        return cameraTransform * markerTransform
    }
    
    // Calculate Euclidean distance between two points
    static func distance(_ p1: simd_float3, _ p2: simd_float3) -> Float {
        return length(p2 - p1)
    }
}

// Extension to extract XYZ components from 4D vector
extension simd_float4 {
    var xyz: simd_float3 { simd_float3(x, y, z) }
} 

// MARK: - Homogeneous Matrix to 3D Position
extension Math {
    /// Extract translation component from homogeneous matrix
    static func homoMatToTipVec(_ mat: simd_float4x4) -> simd_float3 {
        return simd_float3(mat.columns.3.x, mat.columns.3.y, mat.columns.3.z)
    }
}

// MARK: - Tip Position Filtering
extension Math {
    // Buffer for smoothing filter
    static var tipVecBuffer: [SIMD3<Float>] = []
    static let windowSize = 5

    // Apply moving average smoothing to tip position
    static func smoothTipVec(_ tipVec: SIMD3<Float>) -> SIMD3<Float> {
        tipVecBuffer.append(tipVec)
        if tipVecBuffer.count > windowSize {
            tipVecBuffer.removeFirst()
        }
        let sum = tipVecBuffer.reduce(SIMD3<Float>(repeating: 0)) { $0 + $1 }
        return sum / Float(tipVecBuffer.count)
    }
        
    // Jump filtering to remove sudden position changes
    static var lastTipVec: SIMD3<Float>?
    static let maxJump: Float = 0.0005 // Maximum allowed position change

    static func jumpFilter(_ tipVec: SIMD3<Float>) -> SIMD3<Float> {
        if let prevTipVec = lastTipVec {
            let jump = simd_length(tipVec - prevTipVec)
            if jump <= maxJump {
                lastTipVec = tipVec
                return tipVec
            }
        }
        lastTipVec = tipVec
        return tipVec
    }

    // OneEuro filter implementation
    private static var xPrev: SIMD3<Float>?
    private static var dxPrev: SIMD3<Float>?
    private static var tPrev: Double?

    static func oneEuroFilter(_ x: SIMD3<Float>, minCutoff: Float = 1.0, beta: Float = 0.0, dCutoff: Float = 1.0) -> SIMD3<Float> {
        let t = CACurrentMediaTime()
        let dt: Float = tPrev == nil ? 1.0 / 60.0 : Float(t - tPrev!)
        tPrev = t
        let dx = xPrev == nil ? SIMD3<Float>(repeating: 0) : (x - xPrev!) / dt
        let dxHat = lowpass(dx, prev: dxPrev, alpha: alpha(dCutoff, dt: dt))
        let cutoff = minCutoff + beta * simd_length(dxHat)
        let xHat = lowpass(x, prev: xPrev, alpha: alpha(cutoff, dt: dt))
        xPrev = xHat
        dxPrev = dxHat
        return xHat
    }

    // Calculate alpha parameter for lowpass filter
    private static func alpha(_ cutoff: Float, dt: Float) -> Float {
        let tau = 1.0 / (2 * .pi * cutoff)
        return 1.0 / (1.0 + tau / dt)
    }

    // Apply lowpass filter to 3D vector
    private static func lowpass(_ x: SIMD3<Float>, prev: SIMD3<Float>?, alpha: Float) -> SIMD3<Float> {
        guard let prev = prev else { return x }
        return prev * (1 - alpha) + x * alpha
    }
}

// MARK: - Homogeneous Matrix Filter Chain
extension Math {
    // Buffers for matrix filtering
    private static var matrixBuffers: [Int: [simd_float4x4]] = [:]
    private static var matrixPrevs: [Int: simd_float4x4] = [:]
    private static var matrixDxPrevs: [Int: simd_float4x4] = [:]
    private static var matrixTPrevs: [Int: Double] = [:]
    static let matrixWindowSize = 15
    
    // Calculate rotation angle between two matrices (in degrees)
    private static func rotationAngle(_ m1: simd_float4x4, _ m2: simd_float4x4) -> Float {
        let q1 = simd_quaternion(m1)
        let q2 = simd_quaternion(m2)
        let dot = abs(simd_dot(q1.vector, q2.vector))
        // Convert dot product to angle (radians)
        let angle = 2 * acos(min(1, dot))
        // Convert to degrees
        return angle * 180 / .pi
    }
    
    // Apply smoothing filter to transformation matrix
    static func smoothMatrix(_ matrix: simd_float4x4, markerId: Int) -> simd_float4x4 {
        if matrixBuffers[markerId] == nil {
            matrixBuffers[markerId] = []
        }
        matrixBuffers[markerId]!.append(matrix)
        if matrixBuffers[markerId]!.count > matrixWindowSize {
            matrixBuffers[markerId]!.removeFirst()
        }
        
        // Calculate average translation
        let matrices = matrixBuffers[markerId]!
        var avgTranslation = simd_float4.zero
        for m in matrices {
            avgTranslation += m.columns.3
        }
        avgTranslation /= Float(matrices.count)
        
        // Use latest matrix as rotation reference
        var result = matrices.last!
        result.columns.3 = avgTranslation
        return result
    }
    
    // Apply OneEuro filter to transformation matrix
    static func oneEuroMatrixFilter(_ matrix: simd_float4x4, markerId: Int, minCutoff: Float = 2.0, beta: Float = 0.5, dCutoff: Float = 2.0) -> simd_float4x4 {
        let t = CACurrentMediaTime()
        let dt: Float = matrixTPrevs[markerId] == nil ? 1.0 / 60.0 : Float(t - matrixTPrevs[markerId]!)
        matrixTPrevs[markerId] = t
        
        // Calculate velocity (translation part)
        let dx = matrixPrevs[markerId] == nil ? simd_float4x4() : simd_float4x4(
            columns: (
                (matrix.columns.0 - matrixPrevs[markerId]!.columns.0) / dt,
                (matrix.columns.1 - matrixPrevs[markerId]!.columns.1) / dt,
                (matrix.columns.2 - matrixPrevs[markerId]!.columns.2) / dt,
                (matrix.columns.3 - matrixPrevs[markerId]!.columns.3) / dt
            )
        )
        
        // Apply lowpass filter to translation
        let dxHat = lowpassMatrix(dx, prev: matrixDxPrevs[markerId], alpha: alpha(dCutoff, dt: dt))
        
        // Calculate adaptive cutoff frequency
        let cutoff = minCutoff + beta * simd_length(dxHat.columns.3.xyz)
        
        // Apply lowpass filter to translation
        var result = matrix
        let translation = lowpass(matrix.columns.3.xyz, prev: matrixPrevs[markerId]?.columns.3.xyz, alpha: alpha(cutoff, dt: dt))
        result.columns.3 = simd_float4(translation.x, translation.y, translation.z, 1.0)
        
        matrixPrevs[markerId] = result
        matrixDxPrevs[markerId] = dxHat
        return result
    }
    
    // Apply lowpass filter to transformation matrix
    private static func lowpassMatrix(_ x: simd_float4x4, prev: simd_float4x4?, alpha: Float) -> simd_float4x4 {
        guard let prev = prev else { return x }
        var result = simd_float4x4()
        // Apply lowpass filter to translation part
        let translation = lowpass(x.columns.3.xyz, prev: prev.columns.3.xyz, alpha: alpha)
        result.columns.3 = simd_float4(translation.x, translation.y, translation.z, 1.0)
        // Keep rotation part unchanged
        result.columns.0 = x.columns.0
        result.columns.1 = x.columns.1
        result.columns.2 = x.columns.2
        return result
    }
    
    // Apply complete filter chain to transformation matrix
    static func filterHomomatrix(_ matrix: simd_float4x4, markerId: Int) -> simd_float4x4 {
        let smoothed = smoothMatrix(matrix, markerId: markerId)
        return oneEuroMatrixFilter(smoothed, markerId: markerId, minCutoff: 2.0, beta: 0.5, dCutoff: 2.0)
    }
    
    // Clean up filter state for a marker
    static func clearMarkerState(markerId: Int) {
        matrixBuffers[markerId] = nil
        matrixPrevs[markerId] = nil
        matrixDxPrevs[markerId] = nil
        matrixTPrevs[markerId] = nil
    }
}
