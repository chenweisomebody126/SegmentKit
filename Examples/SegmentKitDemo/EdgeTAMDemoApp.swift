import SwiftUI
import EdgeTAMKit

/// SegmentKit Demo App 入口
///
/// 启动时用内置开发密钥配置 SDK（全功能），无需用户输入 License。
/// 打开即用，展示实时视频分割能力。
@main
struct EdgeTAMDemoApp: App {

    init() {
        // 使用开发密钥，解锁全部功能（多目标追踪、无水印）
        try? SegmentKit.configure(licenseKey: "ETK-DEV-UNLIMITED")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
