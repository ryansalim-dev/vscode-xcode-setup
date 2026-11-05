import SwiftUI

@main
struct SampleBazelApp: App {
    init() {
        Greeter.start()
    }

    var body: some Scene {
        WindowGroup { Text("Sample (Bazel)") }
    }
}
