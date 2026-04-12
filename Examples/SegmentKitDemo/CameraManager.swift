import AVFoundation
import CoreVideo
import UIKit

/// 相机管理器 — 封装 AVCaptureSession 提供实时视频帧
///
/// 职责:
///   - 管理 AVCaptureSession 生命周期
///   - 请求相机权限
///   - 输出 CVPixelBuffer 给 tracking pipeline
///   - 提供 AVCaptureVideoPreviewLayer 给 SwiftUI 预览
final class CameraManager: NSObject, ObservableObject {

    // MARK: - 公开状态

    enum AuthorizationStatus {
        case notDetermined
        case authorized
        case denied
    }

    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var isCameraRunning = false
    @Published var error: String?

    /// 每帧回调: 在 capture session queue 上调用
    var onFrame: ((CVPixelBuffer) -> Void)?

    /// 预览视图引用（用 UIImageView 渲染，支持截图）
    weak var previewView: CameraPreviewUIView?

    // MARK: - 内部属性

    let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.edgetamkit.demo.camera", qos: .userInteractive)
    private var videoOutput: AVCaptureVideoDataOutput?

    // MARK: - 权限

    /// 检查并请求相机权限
    func requestAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { self.authorizationStatus = .authorized }
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.authorizationStatus = granted ? .authorized : .denied
                }
                if granted {
                    self.setupSession()
                }
            }
        default:
            DispatchQueue.main.async { self.authorizationStatus = .denied }
        }
    }

    // MARK: - Session 管理

    /// 配置 capture session
    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .hd1280x720

            // 添加后置摄像头输入
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                        for: .video,
                                                        position: .back) else {
                DispatchQueue.main.async { self.error = "找不到后置摄像头" }
                self.captureSession.commitConfiguration()
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                }

                // 配置帧率 30fps
                try camera.lockForConfiguration()
                camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
                camera.unlockForConfiguration()
            } catch {
                DispatchQueue.main.async { self.error = "配置摄像头失败: \(error.localizedDescription)" }
                self.captureSession.commitConfiguration()
                return
            }

            // 添加视频输出
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: self.sessionQueue)

            if self.captureSession.canAddOutput(output) {
                self.captureSession.addOutput(output)
                self.videoOutput = output

                // 设置视频方向为竖屏
                if let connection = output.connection(with: .video) {
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                }
            }

            self.captureSession.commitConfiguration()
        }
    }

    /// 启动相机
    func start() {
        sessionQueue.async { [weak self] in
            guard let self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            DispatchQueue.main.async { self.isCameraRunning = true }
        }
    }

    /// 停止相机
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            DispatchQueue.main.async { self.isCameraRunning = false }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        // 更新预览（UIImageView，支持截图捕获）
        previewView?.updateWithPixelBuffer(pixelBuffer)
        // 回调给追踪 pipeline
        onFrame?(pixelBuffer)
    }
}
