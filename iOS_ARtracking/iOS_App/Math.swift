//
//  Math.swift
//  iOS AR tracking
//
//  Brief: Coordinate transforms and marker pose filtering.
//  This file contains coordinate system transformations, filtering algorithms,
//  and other mathematical utilities used throughout the application.
//

import simd
import ARKit

// MARK: - Pose filter tunable parameters (方便统一调整)
// 说明：下面这些参数控制姿态滤波的“平滑度 vs 跟手性”
// - windowSize：窗口平滑用的帧数，值越大越平滑，但延迟越大
// - oneEuroDefaultMinCutoff：OneEuro 在低速时的基础平滑强度，越小越平滑（但更拖尾）
// - oneEuroChainMinCutoff：综合链路里用的 minCutoff，一般比 default 稍大一点，让最终结果更跟手
// - oneEuroBeta：速度越大时增加多少“跟手性”，越大表示移动时越快跟上（静止时影响不大）
// - oneEuroDCutoff：对速度估计本身的滤波强度，一般保持 2.0 即可，调太小说明速度估计也被过度平滑
// - rotationSlerpAlpha：每一帧朝新旋转插值的比例，越小旋转越稳但反应越慢（0.1 非常稳，0.5 比较灵敏）
enum PoseFilterConfig {
    /// 窗口平滑的窗口长度（帧数）
    static let windowSize: Int = 5

    /// OneEuro 默认参数
    static let oneEuroDefaultMinCutoff: Float = 1.0
    static let oneEuroChainMinCutoff: Float   = 2.0   // 综合链路里用的 minCutoff
    static let oneEuroBeta: Float             = 0.5
    static let oneEuroDCutoff: Float          = 2.0

    /// 旋转 SLERP 的插值系数（0~1，越小越平滑）
    static let rotationSlerpAlpha: Float      = 0.25
}










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








// MARK: - Filter Chain (marker pose filtering)
extension Math {

    // MARK: Shared helpers

    private static func alpha(_ cutoff: Float, dt: Float) -> Float {
        let tau = 1.0 / (2 * .pi * cutoff)
        return 1.0 / (1.0 + tau / dt)
    }
    private static func lowpass(_ x: SIMD3<Float>, prev: SIMD3<Float>?, alpha: Float) -> SIMD3<Float> {
        guard let prev = prev else { return x }
        return prev * (1 - alpha) + x * alpha
    }

    // MARK: Filter state & constants

    // Buffers for matrix filtering
    private static var matrixBuffers: [Int: [simd_float4x4]] = [:]
    private static var matrixPrevs: [Int: simd_float4x4] = [:]
    private static var matrixDxPrevs: [Int: simd_float4x4] = [:]
    private static var matrixTPrevs: [Int: Double] = [:]
    
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
    









    // MARK: Window smoothing (translation only) - frame-average smooth
    
    /// 帧窗口平均平滑：对平移做窗口平均，旋转取最新一帧
    static func frameAvgSmooth(_ matrix: simd_float4x4, markerId: Int) -> simd_float4x4 {
        if matrixBuffers[markerId] == nil {
            matrixBuffers[markerId] = []
        }
        matrixBuffers[markerId]!.append(matrix)
        if matrixBuffers[markerId]!.count > PoseFilterConfig.windowSize {
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
    








    // MARK: Pose filter: OneEuro (translation) + rotation SLERP
    
    /// 对平移使用 OneEuro，对旋转使用四元数 SLERP 的姿态滤波
    static func poseFilterSmooth(
        _ matrix: simd_float4x4,
        markerId: Int,
        minCutoff: Float = PoseFilterConfig.oneEuroDefaultMinCutoff,
        beta: Float = PoseFilterConfig.oneEuroBeta,
        dCutoff: Float = PoseFilterConfig.oneEuroDCutoff
    ) -> simd_float4x4 {
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
        
        // Rotation smoothing via quaternion SLERP
        let currQuat = simd_quaternion(matrix)
        if let prev = matrixPrevs[markerId] {
            let prevQuat = simd_quaternion(prev)
            let smoothedQuat = simd_slerp(prevQuat, currQuat, PoseFilterConfig.rotationSlerpAlpha)
            let rotMat = simd_float4x4(smoothedQuat)
            result.columns.0 = rotMat.columns.0
            result.columns.1 = rotMat.columns.1
            result.columns.2 = rotMat.columns.2
        }
        
        matrixPrevs[markerId] = result
        matrixDxPrevs[markerId] = dxHat
        return result
    }
    
    // MARK: Internal helper: matrix lowpass (translation only)
    
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
    











    // MARK: Combined filter chain & state cleanup
    
    /// 完整链路：先 frameAvgSmooth 再 poseFilterSmooth
    /// frameAvgSmooth  →  poseFilterSmooth
    static func filterHomomatrix(_ matrix: simd_float4x4, markerId: Int) -> simd_float4x4 {
        let smoothed = frameAvgSmooth(matrix, markerId: markerId)
        return poseFilterSmooth(
            smoothed,
            markerId: markerId,
            minCutoff: PoseFilterConfig.oneEuroChainMinCutoff,
            beta: PoseFilterConfig.oneEuroBeta,
            dCutoff: PoseFilterConfig.oneEuroDCutoff
        )
    }
    
    // Clean up filter state for a marker
    static func clearMarkerState(markerId: Int) {
        matrixBuffers[markerId] = nil
        matrixPrevs[markerId] = nil
        matrixDxPrevs[markerId] = nil
        matrixTPrevs[markerId] = nil
    }
}
