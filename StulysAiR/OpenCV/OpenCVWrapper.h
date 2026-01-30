//
//  OpenCVWrapper.h
//  EE267 Project
//
//  Concluded by Chester Pan on 6/3/25
//
//  Brief: Objective-C header file for OpenCV integration.
//  This file defines the interface for marker detection and pose estimation
//  using OpenCV's ArUco module. It provides a bridge between Swift and OpenCV.
//

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

// Class to store marker detection results
@interface MarkerPoseObjC : NSObject
@property (nonatomic) int markerId;               // Marker ID (1-6)
@property (nonatomic) simd_float4x4 transform;    // Transform matrix from camera to marker
@end

// Main wrapper class for OpenCV functionality
@interface OpenCVWrapper : NSObject
// Detect ArUco markers in a pixel buffer and estimate their poses
+ (NSArray<MarkerPoseObjC *> *)detectMarkers:(CVPixelBufferRef)pixelBuffer
                                               intrinsics:(simd_float3x3)K
                                              markerSizeM:(float)markerSize;
@end
NS_ASSUME_NONNULL_END
