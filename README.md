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
    .package(url: "https://github.com/chenweisomebody126/SegmentKit", from: "1.0.0")
]
```

## Quick Start

```swift
import SegmentKit

// 1. Configure with your license key
SegmentKit.configure(licenseKey: "your-license-key")

// 2. Create a tracker
let tracker = try await SKVideoTracker()

// 3. Add a prompt (tap point)
tracker.addPrompt(.point(x: 0.5, y: 0.5, label: .foreground))

// 4. Process frames
let mask = try await tracker.track(frame: pixelBuffer)
```

### SwiftUI Camera View

```swift
import SegmentKit

struct ContentView: View {
    var body: some View {
        SKCameraView { result in
            // result.mask — segmentation mask
            // result.fps  — current processing FPS
        }
    }
}
```

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

The underlying EdgeTAM model is open source under MIT License by Meta Research.

## Support

- Documentation: [segmentkit.dev](https://segmentkit.dev)
- Email: chenweisomebody@gmail.com
- Issues: [GitHub Issues](https://github.com/chenweisomebody126/SegmentKit/issues)
