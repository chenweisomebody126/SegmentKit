// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SegmentKit",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SegmentKit",
            targets: ["SegmentKit"]
        ),
    ],
    targets: [
        // 预编译的 XCFramework（通过 GitHub Release 分发）
        .binaryTarget(
            name: "SegmentKit",
            url: "https://github.com/chenweisomebody126/SegmentKit/releases/download/v1.0.0/SegmentKit.xcframework.zip",
            checksum: "a537e4c8bb278e861480d9cf5bae66e8e39f8e89740a467c6dc405ccb5de3f5c"
        ),
    ]
)
