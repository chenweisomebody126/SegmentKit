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
            url: "https://github.com/chenweisomebody126/SegmentKit/releases/download/v0.5.5/SegmentKit.xcframework.zip",
            checksum: "367991b39a08a3c0af2239ab96df9faededcb1eda5e7e8db47cdc6baa8384184"
        ),
    ]
)
