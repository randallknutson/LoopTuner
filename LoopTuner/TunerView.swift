//
//  TunerView.swift
//  LoopTuner
//
//  Created by Randall Knutson on 6/12/22.
//

import SwiftUI
import HealthKit

struct TunerView: View {
    @EnvironmentObject var settings: SettingsStore
    @State var result: TuneResults?
    @State var days: Int = 30
    @State var calculating: Bool = false
    let healthKitManager = HealthKitManager()

    var body: some View {
        NavigationView {
            VStack {
//                Form {
                    let dayOptions: [Int] = [15, 30, 60, 90]
                    Picker(
                        selection: $days,
                        label: Text("Treatment History")
                    ) {
                        ForEach(values: dayOptions) { value in
                            Text("\(Int(value)) days").tag(value)
                        }
                    }
//                }
                Button(action: {
                    result = nil
                    calculating = true
                    Task.detached {
//                        let bgs = healthKitManager.loadBloodGlucoseCSV()
//                        let carbs = healthKitManager.loadCarbsCSV()
//                        let insulins = healthKitManager.loadInsulinCSV()

                        if HKHealthStore.isHealthDataAvailable() {
                            await healthKitManager.requestAuthorization()
                            let bgs = await healthKitManager.getBloodGlucose(numberOfDays: days)
                            let carbs = await healthKitManager.getCarbs(numberOfDays: days + 1)
                            let insulins = await healthKitManager.getInsulin(numberOfDays: days + 1)
                            
                            do {
                                let autotuner = await Autotuner(settings)
                                let result = try autotuner.tune(bloodGlucoses: bgs, carbs: carbs, insulinDoses: insulins)
                                DispatchQueue.main.async {
                                    self.result = result
                                    self.calculating = false
                                }
                            }
                            catch {
                                
                            }
                        }
                    }
                }) {
                   Text("Calculate")
                }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.large)

                if (calculating) {
                    ProgressView()
                }
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
                            Text(String(format: "%.2f", Double(Int(result!.basal * 20.0))/20.0))
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
