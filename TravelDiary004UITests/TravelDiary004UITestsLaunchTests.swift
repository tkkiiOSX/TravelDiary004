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
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        
        app.buttons["plus"].firstMatch.tap()
        app.textFields["例: 東京旅行"].tap()
        app.textFields["例: 東京旅行"].typeText("おたる水族館３")
        app.buttons["保存"].firstMatch.tap()
        
        app.buttons["おたる水族館３, カード数: 0"].firstMatch.tap()
        app.images["plus.circle"].firstMatch.tap()
        
        let element = app.textFields["カードタイトルを入力"].firstMatch
        element.tap()
        element.tap()
        
        let webButton = app.buttons["webViewButton"].firstMatch
        XCTAssertTrue(webButton.waitForExistence(timeout: 3))
        webButton.tap()
        let webView = app.otherElements["otaru-aquarium-webview"]
        XCTAssertTrue(webView.waitForExistence(timeout: 3))
        
        app.buttons["適用"].firstMatch.tap()
        app.buttons["BackButton"].firstMatch.tap()
        
        
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
