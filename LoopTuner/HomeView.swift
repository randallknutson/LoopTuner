//
//  HomeView.swift
//  LoopTuner
//
//  Created by Randall Knutson on 6/12/22.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("This application will read your HealthKit entries and try to determine the best ISF, CR, and Basal settings for Loop.")
                Text("WARNING: EXPERIMENTAL")
                    .padding()
                    .background(.red)
                    .foregroundColor(.white)
                    .font(.headline)
                Text("This app is highly experimental.")
                    .padding()
                Text("DO NOT use any of the calculated values without consulting your doctor.")
                    .foregroundColor(.red)
                Spacer()
            }
            .padding()
            .navigationTitle("Loop Tuner")
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
