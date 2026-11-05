import BazelApp
import XCTest

final class GreeterTests: XCTestCase {
    func testGreeting() {
        XCTAssertEqual(Greeter.greeting(), "hello-from-sample-app")
    }
}
