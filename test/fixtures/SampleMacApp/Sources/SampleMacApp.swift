import SwiftUI

@main
struct SampleMacApp: App {
    init() {
        Greeter.start()
    }

    var body: some Scene {
        WindowGroup { Text("Sample") }
    }
}
