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
            url: "https://github.com/chenweisomebody126/SegmentKit/releases/download/v0.2.0/SegmentKit.xcframework.zip",
            checksum: "8079ec8d0437d5fccac73f32dd92d22691acd1e31c72c1746d21bf3b6e21cfe8"
        ),
    ]
)
