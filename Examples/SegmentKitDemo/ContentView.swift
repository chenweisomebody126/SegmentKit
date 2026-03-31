import SwiftUI
import EdgeTAMKit

/// 主界面 — 相机预览 + tracking 控制
///
/// 布局:
/// ┌─────────────────────────┐
/// │                         │
/// │    Camera Preview       │
/// │    (带 mask overlay)     │
/// │                         │
/// │         [tap here]      │
/// │                         │
/// ├─────────────────────────┤
/// │ FPS: 34  IoU: 0.95      │
/// │ [Reset]  [Pause]        │
/// └─────────────────────────┘
struct ContentView: View {

    @StateObject private var cameraManager = CameraManager()
    @StateObject private var viewModel = TrackingViewModel()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                // 相机预览
                CameraPreviewView(session: cameraManager.captureSession)
                    .ignoresSafeArea()

                // Mask 叠加层
                if let result = viewModel.currentResult, viewModel.trackingState == .tracking {
                    TrackingOverlayView(trackResult: result)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                // 状态提示（居中）
                stateOverlay

                // 点击手势层
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        let normalized = CGPoint(
                            x: location.x / geometry.size.width,
                            y: location.y / geometry.size.height
                        )
                        viewModel.handleTap(normalizedPoint: normalized)
                    }
                    .ignoresSafeArea()

                // 底部控制栏
                VStack {
                    Spacer()
                    controlBar
                }
            }
        }
        .onAppear {
            cameraManager.requestAuthorization()
            // 将帧回调连接到 ViewModel
            cameraManager.onFrame = { [weak viewModel] buffer in
                viewModel?.processVideoFrame(buffer)
            }
        }
        .onChange(of: cameraManager.authorizationStatus) { newStatus in
            if newStatus == .authorized {
                cameraManager.start()
            }
        }
        .onDisappear {
            cameraManager.stop()
        }
        // 权限被拒绝时的覆盖层
        .overlay {
            if cameraManager.authorizationStatus == .denied {
                permissionDeniedView
            }
        }
    }

    // MARK: - 状态提示

    @ViewBuilder
    private var stateOverlay: some View {
        switch viewModel.trackingState {
        case .idle:
            promptBubble(text: String(localized: "tap_to_track"), icon: "hand.tap")
        case .loading:
            promptBubble(text: String(localized: "initializing"), icon: "gearshape.2")
        case .lost:
            promptBubble(text: String(localized: "target_lost"), icon: "exclamationmark.triangle")
        case .error(let msg):
            errorCard(message: msg)
        case .tracking:
            EmptyView()
        }
    }

    /// 提示气泡
    private func promptBubble(text: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
            Text(text)
                .font(.system(size: 16, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.8))
        .clipShape(Capsule())
    }

    /// 错误卡片
    private func errorCard(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "xmark.circle")
                .font(.system(size: 36))
                .foregroundColor(.red)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button(String(localized: "retry")) {
                viewModel.reset()
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
        .padding(24)
        .background(.ultraThinMaterial.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// 权限被拒绝视图
    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text(String(localized: "camera_permission_title"))
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
            Text(String(localized: "camera_permission_message"))
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button(String(localized: "open_settings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    // MARK: - 底部控制栏

    private var controlBar: some View {
        HStack(spacing: 16) {
            // FPS 和 Confidence 指标
            if viewModel.trackingState == .tracking {
                HStack(spacing: 12) {
                    // FPS
                    HStack(spacing: 4) {
                        Text("FPS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.green)
                        Text("\(Int(viewModel.fps))")
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    }

                    Divider()
                        .frame(height: 16)

                    // IoU
                    HStack(spacing: 4) {
                        Text("IoU")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.cyan)
                        Text(String(format: "%.2f", viewModel.confidence))
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    }

                    Divider()
                        .frame(height: 16)

                    // 帧号
                    Text("#\(viewModel.frameCount)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.gray)
                }
                .foregroundColor(.white)
            }

            Spacer()

            // 暂停/继续
            if viewModel.trackingState == .tracking {
                Button {
                    viewModel.isPaused.toggle()
                } label: {
                    Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 16))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }

            // 重置
            if viewModel.trackingState == .tracking || viewModel.trackingState == .lost {
                Button {
                    viewModel.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.85))
    }
}
