//
//  OpenCVWrapper.mm
//  EE267 Project
//
//  Concluded by Chester Pan on 6/3/25
//  Modified by Cascade on 2/8/26: Updated ArUco API for OpenCV 4.8+ compatibility
//
//  Brief: Objective-C++ implementation file for OpenCV integration.
//  This file implements marker detection and pose estimation using OpenCV's ArUco module.
//  It handles image processing, marker detection, and coordinate system transformations.
//

#import "OpenCVWrapper.h"

// Suppress large number of warnings from OpenCV XCFramework headers
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything"
#if __has_include(<OpenCV/OpenCV.h>)
#import <OpenCV/OpenCV.h>
#elif __has_include(<opencv2/opencv.hpp>)
#include <opencv2/opencv.hpp>
#include <opencv2/aruco.hpp>
#else
#error "OpenCV headers not found. Ensure you added OpenCV.xcframework (iOS) and set Embed & Sign."
#endif
#pragma clang diagnostic pop

using namespace cv;

@implementation MarkerPoseObjC @end

namespace {

// Convert CVPixelBuffer to OpenCV BGR format
inline void pixelBufferToBGR(CVPixelBufferRef pb, cv::Mat &dst) {
    CVPixelBufferLockBaseAddress(pb, kCVPixelBufferLock_ReadOnly);
    int width  = (int)CVPixelBufferGetWidth(pb);
    int height = (int)CVPixelBufferGetHeight(pb);
    void *base = CVPixelBufferGetBaseAddress(pb);
    size_t rowBytes = CVPixelBufferGetBytesPerRow(pb);
    cv::Mat bgra(height, width, CV_8UC4, base, rowBytes);
    cv::cvtColor(bgra, dst, cv::COLOR_BGRA2BGR);
    CVPixelBufferUnlockBaseAddress(pb, kCVPixelBufferLock_ReadOnly);
}

// Convert SIMD camera intrinsics matrix to OpenCV format
inline cv::Mat simdToCv(const simd_float3x3 &K) {
    return (cv::Mat_<double>(3,3) <<
            K.columns[0].x, K.columns[1].x, K.columns[2].x,
            K.columns[0].y, K.columns[1].y, K.columns[2].y,
            K.columns[0].z, K.columns[1].z, K.columns[2].z);
}

// Convert OpenCV rotation vector and translation to SIMD transform matrix
inline simd_float4x4 poseToSimd(const cv::Vec3d &r, const cv::Vec3d &t) {
    cv::Mat R;
    cv::Rodrigues(r, R);  // Convert rotation vector to rotation matrix
    simd_float4x4 T = matrix_identity_float4x4;
    for (int i = 0; i < 3; ++i) {
        for (int j = 0; j < 3; ++j) {
            T.columns[j][i] = static_cast<float>(R.at<double>(i,j));
        }
    }
    T.columns[3] = { (float)t[0], (float)t[1], (float)t[2], 1.0f };
    return T;
}

} // namespace

@implementation OpenCVWrapper

+ (NSArray<MarkerPoseObjC *> *)detectMarkers:(CVPixelBufferRef)pixelBuffer
                                     intrinsics:(simd_float3x3)K
                                    markerSizeM:(float)markerSize {
    // Convert pixel buffer to OpenCV format
    cv::Mat bgr;
    pixelBufferToBGR(pixelBuffer, bgr);
    if (bgr.empty()) {
        // NSLog(@"[OpenCV] bgr.empty()!");
        return @[];
    }

    // Initialize ArUco detector (OpenCV 4.8+ API)
    static cv::aruco::Dictionary dict = cv::aruco::getPredefinedDictionary(cv::aruco::DICT_ARUCO_MIP_36h12);
    static cv::aruco::ArucoDetector detector(dict);

    // Detect markers in the image
    std::vector<int> ids;
    std::vector<std::vector<cv::Point2f>> corners;
    detector.detectMarkers(bgr, corners, ids);
    // NSLog(@"[OpenCV] detectMarkers: ids.size() = %lu", (unsigned long)ids.size());
    for (size_t i = 0; i < ids.size(); ++i) {
        // NSLog(@"[OpenCV] detected id: %d", ids[i]);
    }

    // Filter markers by ID (only accept IDs 2-6)
    std::vector<int> filteredIds;
    std::vector<std::vector<cv::Point2f>> filteredCorners;
    for (size_t i = 0; i < ids.size(); ++i) {
        if (ids[i] >= 2 && ids[i] <= 6) {
            filteredIds.push_back(ids[i]);
            filteredCorners.push_back(corners[i]);
        }
    }
    if (filteredIds.empty()) {
        return @[];
    }

    // Estimate pose for each detected marker using solvePnP (OpenCV 4.8+ API)
    // Define marker corners in object coordinate system (centered at marker)
    float halfSize = markerSize / 2.0f;
    std::vector<cv::Point3f> objPoints = {
        {-halfSize,  halfSize, 0},  // Top-left
        { halfSize,  halfSize, 0},  // Top-right
        { halfSize, -halfSize, 0},  // Bottom-right
        {-halfSize, -halfSize, 0}   // Bottom-left
    };
    
    cv::Mat camMatrix = simdToCv(K);
    cv::Mat distCoeffs = cv::Mat::zeros(1, 5, CV_64F);  // No distortion
    
    std::vector<cv::Vec3d> rvecs, tvecs;
    for (const auto& corners : filteredCorners) {
        cv::Vec3d rvec, tvec;
        cv::solvePnP(objPoints, corners, camMatrix, distCoeffs, rvec, tvec);
        rvecs.push_back(rvec);
        tvecs.push_back(tvec);
    }

    // Convert results to Objective-C objects
    NSMutableArray *result = [NSMutableArray array];
    for (size_t i = 0; i < filteredIds.size(); ++i) {
        MarkerPoseObjC *pose = [MarkerPoseObjC new];
        pose.markerId  = filteredIds[i];
        pose.transform = poseToSimd(rvecs[i], tvecs[i]);
        [result addObject:pose];
    }
    return result;
}

@end
