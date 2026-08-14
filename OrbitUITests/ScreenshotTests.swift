import XCTest

// Automated App Store screenshot capture. Run on an iPhone 16 Pro Max simulator:
//   xcodebuild test -scheme Orbit -destination 'name=iPhone 16 Pro Max' \
//     -resultBundlePath shots.xcresult -only-testing:OrbitUITests
// then: xcrun xcresulttool export attachments --path shots.xcresult --output-path out/
final class ScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    func testCaptureScreenshots() throws {
        var app = launchFresh()

        // First launch on a clean simulator shows onboarding.
        let nameField = app.textFields.firstMatch
        if nameField.waitForExistence(timeout: 3) {
            snap("06-onboarding")
            nameField.tap()
            nameField.typeText("Nova")
            app.buttons["START"].firstMatch.tap()
            sleep(2)
        }

        snap("01-menu")

        // Hangar: tap the pilot card (top card under the title).
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.31)).tap()
        sleep(2)
        snap("08-hangar")
        app.swipeDown(velocity: .fast)
        sleep(2)

        // Classic run: first tap starts, capture the orbiting dot, then a launch.
        let center = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.tap()
        usleep(1_400_000)
        snap("02-gameplay")
        center.tap()
        usleep(350_000)
        snap("03-flight")

        // Leaderboard (fresh launch is the most reliable way back to the menu).
        app = launchFresh()
        let trophy = app.buttons["leaderboardButton"]
        if trophy.waitForExistence(timeout: 4) {
            trophy.tap()
            sleep(3)
            snap("04-leaderboard")
        }

        // Profile
        app = launchFresh()
        let profile = app.buttons["profileButton"]
        if profile.waitForExistence(timeout: 4) {
            profile.tap()
            sleep(2)
            snap("05-profile")
        }

        // Daily challenge run
        app = launchFresh()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.76)).tap()
        usleep(1_500_000)
        snap("07-daily")
    }

    // Captures the paywall for the subscription review-information screenshot.
    // The scheme's StoreKit configuration supplies the two products.
    func testPaywallShot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-screenshots", "-fakestore",
                               "-progress.xp", "230", "-bestScore", "47"]
        app.launch()
        sleep(3)
        let nameField = app.textFields.firstMatch
        if nameField.waitForExistence(timeout: 3) {
            nameField.tap()
            nameField.typeText("Nova")
            app.buttons["START"].firstMatch.tap()
            sleep(2)
        }
        let star = app.buttons["premiumButton"]
        if star.waitForExistence(timeout: 4) {
            star.tap()
            sleep(3)
            snap("09-paywall")
        }
    }

    // Drives ~30s of real gameplay for the App Store preview video recording.
    // Run alone with -only-testing while `simctl io recordVideo` captures.
    func testPreviewDrive() throws {
        let app = launchFresh()
        let nameField = app.textFields.firstMatch
        if nameField.waitForExistence(timeout: 3) {
            nameField.tap()
            nameField.typeText("Nova")
            app.buttons["START"].firstMatch.tap()
            sleep(2)
        }
        sleep(2)
        let center = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.tap()   // menu → classic run
        for _ in 0..<26 {
            usleep(1_150_000)
            center.tap()   // launches; on a death this same tap retries
        }
        sleep(2)
    }

    private func launchFresh() -> XCUIApplication {
        let app = XCUIApplication()
        // The extra pairs pre-seed UserDefaults (argument domain) so the menu
        // shows a lived-in pilot level, XP bar, and best score.
        app.launchArguments = ["-screenshots", "-progress.xp", "230", "-bestScore", "47"]
        app.launch()
        sleep(3) // splash + settle
        return app
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
