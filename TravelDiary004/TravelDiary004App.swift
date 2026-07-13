//
//  TravelDiary004App.swift
//  TravelDiary004
//
//  Created by Xcode2021 on 2026/05/31.
//

import SwiftUI

@main
struct TravelDiary004App: App {
    @StateObject private var model = TravelDataModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .onOpenURL { url in
                    Task { @MainActor in
                        _ = model.importSheet(from: url)
                    }
                }
        }
    }
}
