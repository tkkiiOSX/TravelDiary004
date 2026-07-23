//
//  ContentView.swift
//  TravelDiary004
//
//  Created by Xcode2021 on 2026/05/31.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: TravelDataModel

    var body: some View {
        SheetListView()
    }
}

#Preview {
    ContentView().environmentObject(TravelDataModel())
}


