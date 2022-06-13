//
//  ContentView.swift
//  LoopTuner
//
//  Created by Randall Knutson on 5/16/22.
//

import SwiftUI
import HealthKit

struct Tuner: View {
    let settings = SettingsStore()
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            TunerView()
                .tabItem {
                    Label("Tune", systemImage: "wand.and.stars")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .environmentObject(settings)
    }
}

struct Tuner_Previews: PreviewProvider {
    static var previews: some View {
        Tuner()
    }
}
