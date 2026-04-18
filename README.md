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
    .package(url: "https://github.com/chenweisomebody126/SegmentKit", from: "0.4.1")
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

## API Overview

### Core Types

| Type | Description |
|------|-------------|
| [`ETKSegmenter`](#etksegmenter) | Main entry point — create, configure, and run segmentation |
| [`ETKSegmenterOptions`](#etksegmenteroptions) | Configuration options (mode, performance, multi-object) |
| [`ETKPrompt`](#etkprompt) | What to segment — point, box, mask, or combination |
| [`ETKTrackResult`](#etktrackresult) | Per-frame tracking output (mask, confidence, overlay) |
| [`ETKSegmentResult`](#etksegmentresult) | Single-image segmentation output |

### ETKSegmenter

Three running modes for different use cases:

```swift
// Image mode — single frame, no state
options.runningMode = .image
let result = try segmenter.segment(image: photo, prompt: .point(tap))

// Video mode — synchronous, frame-by-frame
options.runningMode = .video
let first = try segmenter.segment(videoFrame: frame, prompt: .point(tap), timestampMs: 0)
let next  = try segmenter.segment(videoFrame: frame, timestampMs: 33)  // auto-track

// LiveStream mode — async, camera pipeline
options.runningMode = .liveStream
options.liveStreamDelegate = self
try segmenter.segmentAsync(frame: pixelBuffer, prompt: .point(tap), timestampMs: ts)
```

### ETKSegmenterOptions

| Property | Default | Description |
|----------|---------|-------------|
| `runningMode` | `.image` | `.image` / `.video` / `.liveStream` |
| `maxObjects` | `1` | Multi-object tracking (1–10). Each +1 object ≈ +3ms |
| `memoryFrames` | `7` | Temporal memory depth (1–7). More = stabler tracking |
| `interleavingEnabled` | `true` | IE∥MA parallel execution. ~29ms vs ~80ms per frame |
| `computeUnit` | `.auto` | `.auto` / `.cpuAndANE` / `.cpuAndGPU` |

### ETKPrompt

All coordinates are **normalized (0–1)**, origin at top-left.

```swift
// Single foreground point
.point(CGPoint(x: 0.5, y: 0.5))

// Foreground + background points
.points([
    ETKLabeledPoint(point: target, label: .foreground),
    ETKLabeledPoint(point: exclude, label: .background),
])

// Bounding box
.boundingBox(CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.3))

// Combine prompts
.combined([.boundingBox(rect), .points([bg])])
```

### ETKTrackResult

```swift
result.mask            // [Float] — 256×256 logits (positive = foreground)
result.confidence      // Float — IoU score (0–1)
result.isTracking      // Bool — target still visible?
result.binaryMask      // [Bool] — thresholded at 0
result.probabilityMask // [Float] — sigmoid probabilities

// Render overlay directly
let overlay = result.overlayImage(on: frame, color: .systemBlue, opacity: 0.4)
```

### Multi-Object Tracking

Track multiple objects simultaneously (requires `maxObjects > 1`):

```swift
options.maxObjects = 3
let segmenter = try ETKSegmenter(options: options)

// First frame — provide all prompts
let results = try segmenter.segment(
    videoFrame: frame,
    prompts: [
        0: .point(leftFoot),
        1: .point(rightFoot),
    ],
    timestampMs: 0
)
// results[0] → left foot mask, results[1] → right foot mask

// Subsequent frames — auto-track all objects
let tracked = try segmenter.segmentMulti(videoFrame: frame, timestampMs: 33)
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

- [Quick Start](#quick-start) — Get running in 4 lines
- [API Overview](#api-overview) — Core types and usage patterns
- [Example App](Examples/SegmentKitDemo/) — Complete demo with camera + tap-to-track
- [segmentkit.dev](https://segmentkit.dev) — Website and pricing

## License

SegmentKit is a commercial SDK. See [LICENSE](LICENSE) for details.

The underlying EdgeTAM model is open source under Apache License 2.0 by Meta Platforms, Inc. See [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES) for details.

## Support

- Documentation: [segmentkit.dev](https://segmentkit.dev)
- Email: chenweisomebody@gmail.com
- Issues: [GitHub Issues](https://github.com/chenweisomebody126/SegmentKit/issues)
