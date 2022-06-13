//
//  TunerView.swift
//  LoopTuner
//
//  Created by Randall Knutson on 6/12/22.
//

import SwiftUI

struct TunerView: View {
    let healthKitManager = HealthKitManager()
    @State var result: TuneResults?

    var body: some View {
        NavigationView {
            VStack {
                Button(action: {
                    Task {
                        let bgs = healthKitManager.loadBloodGlucoseCSV()
                        let carbs = healthKitManager.loadCarbsCSV()
                        let insulins = healthKitManager.loadInsulinCSV()
                        
                        do {
                            let autotuner = Autotuner()
                            result = try autotuner.tune(bloodGlucoses: bgs, carbs: carbs, insulinDoses: insulins)
                        }
                        catch {
                            
                        }
                    }
                }) {
                   Text("Calculate")
                }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.large)
    
                if (result != nil) {
                    Divider()
                    VStack {
                        HStack {
                            Text("ISF")
                                .font(.largeTitle)
                            Spacer()
                            Text(String(format: "%.1f", result!.isf))
                                .font(.headline)
                                .padding()
                                .border(.primary)
                        }
                        HStack {
                            Text("CR")
                                .font(.largeTitle)
                            Spacer()
                            Text(String(format: "%.1f", result!.cr))
                                .font(.headline)
                                .padding()
                                .border(.primary)
                        }
                        HStack {
                            Text("Basal")
                                .font(.largeTitle)
                            Spacer()
                            Text(String(format: "%.1f", result!.basal))
                                .font(.headline)
                                .padding()
                                .border(.primary)
                        }
                        HStack {
                            Text("Error %")
                                .font(.largeTitle)
                            Spacer()
                            Text(String(format: "%.1f", result!.rmse))
                                .font(.headline)
                                .padding()
                                .border(.primary)
                        }
                    }
                        .padding()
                }
                Spacer()
            }
            .navigationTitle("Tune")
        }
    }
}

struct TunerView_Previews: PreviewProvider {
    static var previews: some View {
        TunerView()
    }
}
