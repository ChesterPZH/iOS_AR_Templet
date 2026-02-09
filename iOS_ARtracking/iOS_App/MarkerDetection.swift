//
//  MarkerDetection.swift
//  EE267 Project
//
//  Concluded by Chester Pan on 6/3/25
//
//  Brief: Handles marker detection and camera image processing.
//  This class manages the preprocessing of camera images for marker detection,
//  including format conversion, resizing, and camera intrinsics adjustment.
//

import ARKit
import SceneKit
import UIKit
import CoreImage

// MARK: - Marker detection configuration (which markers, size, image scaling)

enum MarkerDetectionConfig {
    /// 所有 marker 的物理边长（单位：米，假设相同）
    /// 例如：3cm 的码就是 0.03
    static let markerSizeM: Float = 0.03

    /// 下采样后的检测分辨率（越小越快，越大越准）
    static let targetWidth: Int  = 960
    static let targetHeight: Int = 540
}











// Structure to store marker tracking information
struct MarkerInfo: Hashable {
    let id: Int                // Marker ID
    let homoMat: simd_float4x4 // Homogeneous transformation matrix

    // Equality comparison
    static func == (lhs: MarkerInfo, rhs: MarkerInfo) -> Bool {
        lhs.id == rhs.id && lhs.homoMat == rhs.homoMat
    }

    // Hash function for dictionary key
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        // Hash each row of the matrix
        for i in 0..<4 {
            hasher.combine(homoMat[i].x)
            hasher.combine(homoMat[i].y)
            hasher.combine(homoMat[i].z)
            hasher.combine(homoMat[i].w)
        }
    }
}

/// Singleton: Handles marker detection and camera intrinsics adjustment
final class MarkerDetection: NSObject {

    static let shared = MarkerDetection()
    private override init() {}

    // Convert pixel buffer to BGRA format
    func pixelBufferBGRA(from pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        if pixelFormat == kCVPixelFormatType_32BGRA {
            return pixelBuffer
        }
        
        // Convert to BGRA format
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        var bgraBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ] as CFDictionary
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs,
            &bgraBuffer
        )
        if let bgraBuffer = bgraBuffer {
            context.render(ciImage, to: bgraBuffer)
            return bgraBuffer
        }
        return nil
    }

    // Resize pixel buffer to target dimensions
    func resizePixelBuffer(_ pixelBuffer: CVPixelBuffer, width: Int, height: Int) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        // Calculate scale factors
        let scaleX = CGFloat(width) / CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let scaleY = CGFloat(height) / CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        // Create output buffer
        var outputBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ] as CFDictionary
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs,
            &outputBuffer
        )
        if let outputBuffer = outputBuffer {
            context.render(scaledImage, to: outputBuffer)
            return outputBuffer
        }
        return nil
    }

    // Adjust camera intrinsics for resized image
    func adjustCameraIntrinsics(_ intrinsics: simd_float3x3, _ pixelBuffer: CVPixelBuffer, _ targetWidth: Int, _ targetHeight: Int) -> simd_float3x3 {
        let origWidth = Float(CVPixelBufferGetWidth(pixelBuffer))
        let origHeight = Float(CVPixelBufferGetHeight(pixelBuffer))
        let newWidth = Float(targetWidth)
        let newHeight = Float(targetHeight)
        
        // Calculate scale factors
        var K = intrinsics
        let scaleX = newWidth / origWidth
        let scaleY = newHeight / origHeight
        
        // Adjust focal lengths
        K.columns.0.x *= scaleX // fx
        K.columns.1.y *= scaleY // fy
        
        // Adjust principal point
        K.columns.2.x = (K.columns.2.x + 0.5) * scaleX - 0.5
        K.columns.2.y = (K.columns.2.y + 0.5) * scaleY - 0.5
        
        return K
    }
} 