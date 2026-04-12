import CoreVideo
import EdgeTAMKit
import Foundation
import UIKit

/// 追踪状态机
enum TrackingState: Equatable {
    /// 已停止 — 模型未加载，相机未启动，不占用资源
    case stopped
    /// 模型加载中
    case loading
    /// 就绪 — 模型已加载，等待用户 tap
    case ready
    /// 追踪中
    case tracking
    /// 目标丢失
    case lost
    /// 错误
    case error(String)

    static func == (lhs: TrackingState, rhs: TrackingState) -> Bool {
        switch (lhs, rhs) {
        case (.stopped, .stopped), (.loading, .loading),
             (.ready, .ready), (.tracking, .tracking), (.lost, .lost):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

/// 追踪视图模型 — 管理 ETKSegmenter (liveStream 模式) 完整生命周期
///
/// 生命周期:
///   stopped → start() → loading → ready → tap → tracking → stop() → stopped
///
/// start() 加载模型 + 启动相机
/// stop()  释放模型 + 停止相机，完全释放内存
final class TrackingViewModel: ObservableObject, ETKSegmenterLiveStreamDelegate {

    // MARK: - UI 状态 (MainActor)

    @Published var trackingState: TrackingState = .stopped
    @Published var currentResult: ETKTrackResult?
    @Published var confidence: Float = 0
    @Published var fps: Double = 0
    @Published var frameCount: Int = 0
    @Published var isPaused = false

    // MARK: - 内部状态

    private var segmenter: ETKSegmenter?
    private var isPreloading = false

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

    // MARK: - 生命周期

    /// 启动 — 加载模型 + 启动相机
    func start() {
        guard trackingState == .stopped || trackingState == .error("") || {
            if case .error = trackingState { return true }
            return false
        }() else { return }
        guard !isPreloading else { return }

        trackingState = .loading
        isPreloading = true

        // 启动相机
        cameraManager?.start()

        // 后台加载模型
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let options = ETKSegmenterOptions()
                options.runningMode = .liveStream
                options.liveStreamDelegate = self
                let s = try ETKSegmenter(options: options)

                DispatchQueue.main.async {
                    guard let self else { return }
                    self.segmenter = s
                    self.isPreloading = false
                    self.trackingState = .ready
                }
            } catch {
                DispatchQueue.main.async {
                    self?.trackingState = .error(error.localizedDescription)
                    self?.isPreloading = false
                }
            }
        }
    }

    /// 停止 — 释放模型 + 停止相机，完全释放内存
    func stop() {
        // 停止相机
        cameraManager?.stop()

        // 释放模型
        segmenter = nil
        isPreloading = false
        pendingTapPoint = nil
        timestampMs = 0

        // 重置所有 UI 状态
        trackingState = .stopped
        currentResult = nil
        confidence = 0
        fps = 0
        frameCount = 0
        isPaused = false
        lastFrameTime = 0
        fpsAccumulator = 0
        fpsFrameCount = 0
    }

    // MARK: - 追踪操作

    /// 处理用户点击 — 开始追踪
    func handleTap(normalizedPoint: CGPoint) {
        switch trackingState {
        case .ready, .lost:
            break
        default:
            return
        }

        // 如果之前追踪过，先 reset
        if trackingState == .lost || currentResult != nil {
            segmenter?.reset()
        }

        trackingState = .loading
        timestampMs = 0
        pendingTapPoint = normalizedPoint
    }

    /// 重置追踪（保留模型和相机，回到 ready 状态）
    func resetTracking() {
        segmenter?.reset()
        pendingTapPoint = nil
        timestampMs = 0

        trackingState = .ready
        currentResult = nil
        confidence = 0
        fps = 0
        frameCount = 0
        isPaused = false
        lastFrameTime = 0
        fpsAccumulator = 0
        fpsFrameCount = 0
    }

    // MARK: - 帧处理

    /// 处理相机帧 — 在 camera capture queue 上调用
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

        // 后续帧: 自动追踪
        guard trackingState == .tracking || trackingState == .loading else { return }

        try? segmenter?.segmentAsync(
            frame: pixelBuffer,
            timestampMs: timestampMs
        )
    }

    // MARK: - ETKSegmenterLiveStreamDelegate

    func segmenter(_ segmenter: ETKSegmenter,
                   didFinishWith result: ETKTrackResult?,
                   timestampMs: Int,
                   error: Error?) {
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
