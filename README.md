# SegmentKit

Real-time video object segmentation SDK for iOS. Powered by [EdgeTAM](https://github.com/facebookresearch/EdgeTAM).

Track any object in real-time video at 30+ FPS on iPhone — just tap to select.

## Features

- **Real-time performance** — 30+ FPS on iPhone 14 Pro and later
- **Tap-to-track** — Point, box, or mask prompts
- **Zero-copy Metal pipeline** — CoreML + Metal with no CPU overhead
- **Streaming memory** — Constant memory usage regardless of video length
- **Drop-in camera view** — SwiftUI `SKCameraView` with built-in UI
- **Offline license validation** — Ed25519 signed keys, no network required

## Requirements

- iOS 17.0+
- Xcode 16.0+
- iPhone 14 Pro or later (A16+ with Neural Engine)

## Installation

### Swift Package Manager

Add SegmentKit to your project via Xcode:

1. File → Add Package Dependencies
2. Enter: `https://github.com/chenweisomebody126/SegmentKit`
3. Select version and add to your target

Or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/chenweisomebody126/SegmentKit", from: "0.2.0")
]
```

## Quick Start

```swift
import EdgeTAMKit

// 1. Configure with your license key (or use free mode)
try SegmentKit.configure(licenseKey: "your-license-key")

// 2. Create a segmenter (liveStream mode for real-time camera)
let options = ETKSegmenterOptions()
options.runningMode = .liveStream
options.liveStreamDelegate = self
let segmenter = try ETKSegmenter(options: options)

// 3. Send camera frames — SDK handles frame dropping automatically
try segmenter.segmentAsync(
    frame: pixelBuffer,
    prompt: .point(tapPoint),   // first frame needs a prompt
    timestampMs: timestampMs
)

// 4. Receive results via delegate
func segmenter(_ segmenter: ETKSegmenter,
               didFinishWith result: ETKTrackResult?,
               timestampMs: Int, error: Error?) {
    guard let result else { return }
    // result.mask — 256×256 segmentation mask
    // result.confidence — IoU score
    // result.isTracking — target still visible?
}
```

## Example App

See [`Examples/SegmentKitDemo/`](Examples/SegmentKitDemo/) for a complete, runnable demo app with camera preview, tap-to-track, and mask overlay — localized in English and Chinese.

## Pricing

| Plan | Price | Features |
|------|-------|----------|
| **Free Trial** | $0 / 7 days | Full access, no credit card required |
| **Indie** | $49/mo | Commercial license, no watermark |
| **Pro** | $199/mo | Multi-target, custom models, priority support |
| **Enterprise** | Custom | Dedicated engineer, SLA |

Start your free trial at [segmentkit.dev](https://segmentkit.dev).

## Documentation

Full documentation available at [segmentkit.dev/docs](https://segmentkit.dev#docs).

## License

SegmentKit is a commercial SDK. See [LICENSE](LICENSE) for details.

The underlying EdgeTAM model is open source under Apache License 2.0 by Meta Platforms, Inc. See [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES) for details.

## Support

- Documentation: [segmentkit.dev](https://segmentkit.dev)
- Email: chenweisomebody@gmail.com
- Issues: [GitHub Issues](https://github.com/chenweisomebody126/SegmentKit/issues)
