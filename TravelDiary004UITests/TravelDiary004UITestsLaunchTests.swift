//
//  TravelDiary004UITestsLaunchTests.swift
//  TravelDiary004UITests
//
//  Created by Xcode2021 on 2026/07/11.
//

import XCTest

final class TravelDiary004UITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchWithSampleSheets() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-uiTestingResetData")
        app.launch()

        let sampleTitles = [
            "青森旅行",
            "長野旅行",
            "東京旅行",
            "名古屋旅行",
            "京都旅行",
            "大阪旅行",
            "神戸旅行",
            "広島旅行",
            "福岡旅行"
        ]

        for title in sampleTitles {
            addSheet(title: title, in: app)
        }

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Sample Travel Sheets"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func addSheet(title: String, in app: XCUIApplication) {
        app.buttons["plus"].firstMatch.tap()

        let titleField = app.textFields["例: 東京旅行"].firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText(title)

        app.buttons["保存"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts[title].firstMatch.waitForExistence(timeout: 3))
    }
}
