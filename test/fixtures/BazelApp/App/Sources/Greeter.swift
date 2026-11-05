import Foundation

public enum Greeter {
    static var ticks = 0

    public static func greeting() -> String {
        "hello-from-sample-app"
    }

    public static func start() {
        let message = greeting()
        print(message) // CI_BREAKPOINT
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            ticks += 1
            print("tick \(ticks)")
        }
    }
}
