// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "OpenCV",
  platforms: [
    .macOS(.v14), .iOS(.v17), .macCatalyst(.v17)
  ],
  products: [
    .library(name: "OpenCV",
             targets: ["OpenCV"]
             ),
  ],
  targets: [
     .binaryTarget(name: "OpenCV",
                  url: "https://github.com/r0ml/OpenCV/releases/download/4.12.0/OpenCV.xcframework.zip",
                  checksum: "7396cdb9cd39c9f281460fd2d568a77286d198285457f922f646f589d841e9dd"),
  ]
)

