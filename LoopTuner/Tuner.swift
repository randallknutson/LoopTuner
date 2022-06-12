//
//  ContentView.swift
//  LoopTuner
//
//  Created by Randall Knutson on 5/16/22.
//

import SwiftUI
import HealthKit

struct Tuner: View {
    let healthKitManager = HealthKitManager();
    
    func getIndex(startDate: TimeInterval, currentDate: TimeInterval) -> Int {
        return Int(currentDate - startDate) / 300
    }

    var body: some View {
        VStack {
            Text("Loop Tuner")
                .padding()
            
            Button(action: {
                Task {
                    let bgs = healthKitManager.loadBloodGlucoseCSV()
                    let carbs = healthKitManager.loadCarbsCSV()
                    let insulins = healthKitManager.loadInsulinCSV()
                    
                    let autotuner = Autotuner()
                    autotuner.convertHealthKitToMLDataTable(bloodGlucoses: bgs, carbs: carbs, insulinDoses: insulins)
                    print ("Done")
                }
            }) {
               Text("Calculate")
            }
        }
    }
}

struct Tuner_Previews: PreviewProvider {
    static var previews: some View {
        Tuner()
    }
}
