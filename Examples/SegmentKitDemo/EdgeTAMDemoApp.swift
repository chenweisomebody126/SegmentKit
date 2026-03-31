import SwiftUI
import EdgeTAMKit

/// SegmentKit Demo App
///
/// To unlock all features, get a license key at https://segmentkit.dev
/// Then replace `SegmentKit.configure()` with:
///   `try SegmentKit.configure(licenseKey: "YOUR_KEY")`
@main
struct SegmentKitDemoApp: App {

    init() {
        // Free mode — single target tracking with watermark
        // Get a trial key at https://segmentkit.dev for full features
        SegmentKit.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
