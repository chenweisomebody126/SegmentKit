import CoreVideo
import EdgeTAMKit
import Foundation
import UIKit

/// 追踪状态机
enum TrackingState: Equatable {
    case idle
    case loading
    case tracking
    case lost
    case error(String)

    static func == (lhs: TrackingState, rhs: TrackingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading),
             (.tracking, .tracking), (.lost, .lost):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

/// 追踪视图模型 — 管理 ETKSegmenter (liveStream 模式) 生命周期
///
/// 使用 liveStream 模式:
///   - segmentAsync() fire-and-forget，SDK 自动丢帧
///   - 结果通过 ETKSegmenterLiveStreamDelegate 回调到 asyncQueue
///   - ViewModel 在 delegate 中 dispatch 到 MainActor 更新 UI
///
/// 调用者只需在相机帧到达时调用 processVideoFrame()。
final class TrackingViewModel: ObservableObject, ETKSegmenterLiveStreamDelegate {

    // MARK: - UI 状态 (MainActor)

    @Published var trackingState: TrackingState = .idle
    @Published var currentResult: ETKTrackResult?
    @Published var confidence: Float = 0
    @Published var fps: Double = 0
    @Published var frameCount: Int = 0
    @Published var isPaused = false

    // MARK: - 内部状态

    private var segmenter: ETKSegmenter?

    /// 暂存的点击坐标（等待下一帧触发首帧处理）
    private var pendingTapPoint: CGPoint?

    /// 帧时间戳（毫秒，单调递增）— 仅在 camera 回调线程访问
    private var timestampMs: Int = 0

    /// FPS 计算
    private var lastFrameTime: CFAbsoluteTime = 0
    private var fpsAccumulator: Double = 0
    private var fpsFrameCount: Int = 0

    /// 相机管理器引用（弱引用避免循环）
    weak var cameraManager: CameraManager?

    // MARK: - 公开接口

    /// 处理用户点击 — 初始化追踪
    func handleTap(normalizedPoint: CGPoint) {
        // 只在 idle 或 lost 状态响应
        switch trackingState {
        case .idle, .lost:
            break
        default:
            return
        }

        trackingState = .loading

        // 初始化或重置 segmenter（liveStream 模式）
        do {
            if segmenter == nil {
                let options = ETKSegmenterOptions()
                options.runningMode = .liveStream
                options.liveStreamDelegate = self
                segmenter = try ETKSegmenter(options: options)
            } else {
                segmenter?.reset()
            }

            // 重置时间戳
            timestampMs = 0

            // 暂存点击坐标，等下一帧到达时发送带 prompt 的 segmentAsync
            pendingTapPoint = normalizedPoint

        } catch {
            trackingState = .error(error.localizedDescription)
        }
    }

    /// 处理相机帧 — 在 camera capture queue 上调用
    ///
    /// 直接调用 segmentAsync()，SDK 负责丢帧。
    /// 不需要手动管理 isProcessingFrame。
    func processVideoFrame(_ pixelBuffer: CVPixelBuffer) {
        guard !isPaused, segmenter != nil else { return }

        timestampMs += 33  // ~30fps

        if let point = pendingTapPoint {
            // 首帧: 带 prompt
            pendingTapPoint = nil
            do {
                try segmenter?.segmentAsync(
                    frame: pixelBuffer,
                    prompt: .point(point),
                    timestampMs: timestampMs
                )
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.trackingState = .error(error.localizedDescription)
                }
            }
            return
        }

        // 后续帧: 自动追踪（无 prompt）
        // segmentAsync 会在上一帧还在处理时自动丢弃，无需外部判断
        guard trackingState == .tracking || trackingState == .loading else { return }

        try? segmenter?.segmentAsync(
            frame: pixelBuffer,
            timestampMs: timestampMs
        )
    }

    /// 重置追踪
    func reset() {
        segmenter?.reset()
        pendingTapPoint = nil
        timestampMs = 0

        trackingState = .idle
        currentResult = nil
        confidence = 0
        fps = 0
        frameCount = 0
        isPaused = false
        lastFrameTime = 0
        fpsAccumulator = 0
        fpsFrameCount = 0
    }

    // MARK: - ETKSegmenterLiveStreamDelegate
    //
    // 回调在 SDK 内部串行队列执行（非主线程）。
    // 所有 UI 更新 dispatch 到 main。

    func segmenter(_ segmenter: ETKSegmenter,
                   didFinishWith result: ETKTrackResult?,
                   timestampMs: Int,
                   error: Error?) {
        // 计算 FPS（在回调线程）
        let now = CFAbsoluteTimeGetCurrent()
        var newFps: Double?

        if lastFrameTime > 0 {
            let delta = now - lastFrameTime
            if delta > 0 {
                fpsAccumulator += 1.0 / delta
                fpsFrameCount += 1

                if fpsFrameCount >= 10 {
                    newFps = fpsAccumulator / Double(fpsFrameCount)
                    fpsAccumulator = 0
                    fpsFrameCount = 0
                }
            }
        }
        lastFrameTime = now

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if let error {
                self.trackingState = .error(error.localizedDescription)
                return
            }

            guard let result else { return }

            self.currentResult = result
            self.confidence = result.confidence
            self.frameCount = result.frameIndex + 1

            if let f = newFps {
                self.fps = f
            }

            if result.isTracking {
                if self.trackingState != .tracking {
                    self.trackingState = .tracking
                }
            } else {
                self.trackingState = .lost
            }
        }
    }
}
