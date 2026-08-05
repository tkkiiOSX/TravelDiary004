//
//  TravelDiary004UITestsLaunchTests.swift
//  TravelDiary004UITests
//
//  Created by Xcode2021 on 2026/07/11.
//

import XCTest

final class TravelDiary004UITestsLaunchTests: XCTestCase {
    private let timeout: TimeInterval = 10

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
        waitForHomeScreen(in: app)

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
    }

    @MainActor
    private func addSheet(title: String, in app: XCUIApplication) {
        let addButton = app.buttons["plus"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: timeout))
        addButton.tap()

        let titleField = app.textFields["例: 東京旅行"].firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: timeout))
        titleField.tap()
        titleField.typeText(title)

        let saveButton = app.buttons["保存"].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: timeout))
        saveButton.tap()

        let savedTitle = app.staticTexts[title].firstMatch
        XCTAssertTrue(savedTitle.waitForExistence(timeout: timeout))
        XCTAssertTrue(addButton.waitForExistence(timeout: timeout))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = title
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func waitForHomeScreen(in app: XCUIApplication) {
        let addButton = app.buttons["plus"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: timeout))
    }
}
