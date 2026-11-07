import XCTest
@testable import GagaEmu

/// Every test runs with its own empty Library, ROMs and System folders (`AppState.rootOverride`), so no test reads
/// or changes the Library saved on the device, even one stopped before its clean-up ran. In `invokeTest`, not
/// `setUp`, so a subclass's own `setUp` cannot skip it.
class GagaTestCase: XCTestCase {
    override func invokeTest() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("gaga-test-\(UUID().uuidString)", isDirectory: true)
        AppState.rootOverride = root
        defer {
            AppState.rootOverride = nil
            try? FileManager.default.removeItem(at: root)
        }
        super.invokeTest()
    }
}
