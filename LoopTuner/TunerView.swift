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
    @State var result: [TuneResults] = []
    @State var days: Int = 30
    @State var calculating: Bool = false
    let healthKitManager = HealthKitManager()

    var body: some View {
        NavigationView {
            VStack {
                    let dayOptions: [Int] = [15, 30, 60, 90]
                    Picker(
                        selection: $days,
                        label: Text("Treatment History")
                    ) {
                        ForEach(values: dayOptions) { value in
                            Text("\(Int(value)) days").tag(value)
                        }
                    }
                Button(action: {
                    result = []
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
                    .disabled(calculating)

                if (calculating) {
                    ProgressView()
                }
                if (result.count != 0) {
                    Divider()
                    VStack {
                        HStack {
                            Text("Period")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("ISF")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("CR")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Basal")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Error %")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        ForEach(result) { tuned in
                            HStack {
                                Text(tuned.period)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(tuned.isfString)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(tuned.crString)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(tuned.basalString)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(tuned.rmseString)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
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
