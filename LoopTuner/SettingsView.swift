//
//  SettingsView.swift
//  LoopTuner
//
//  Created by Randall Knutson on 6/12/22.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Insulin Settings")) {
                    let insulinDelays: [Double] = [5, 10, 15, 20, 25, 30]
                    Picker(
                        selection: $settings.insulinDelay,
                        label: Text("Delay")
                    ) {
                        ForEach(values: insulinDelays) { value in
                            Text("\(Int(value)) minutes").tag(TimeInterval.minutes(value))
                        }
                    }

                    let insulinActionDurations: [Double] = [4, 5, 5.5, 6, 6.5, 7]
                    Picker(
                        selection: $settings.insulinActionDuration,
                        label: Text("Action Duration")
                    ) {
                        ForEach(values: insulinActionDurations) { value in
                            Text("\(String(format: "%.1f", value)) hours").tag(TimeInterval.hours(value))
                        }
                    }

                    let insulinPeakActivityTimes: [Double] = [45, 50, 55, 60, 65, 70, 75]
                    Picker(
                        selection: $settings.insulinPeakActivityTime,
                        label: Text("Peak Activity Time")
                    ) {
                        ForEach(values: insulinPeakActivityTimes) { value in
                            Text("\(Int(value)) minutes").tag(TimeInterval.minutes(value))
                        }
                    }
                }
                Section(header: Text("Carb Settings")) {
                    let carbsDelays: [Double] = [5, 10, 15, 20, 25, 30]
                    Picker(
                        selection: $settings.carbsDelay,
                        label: Text("Delay")
                    ) {
                        ForEach(values: carbsDelays) { value in
                            Text("\(Int(value)) minutes").tag(TimeInterval.minutes(value))
                        }
                    }

                    let carbsDefaultAbsorptionTimes: [Double] = [2.5, 2.75, 3, 3.25, 3.5]
                    Picker(
                        selection: $settings.carbsDefaultAbsorptionTime,
                        label: Text("Default Absorption Time")
                    ) {
                        ForEach(values: carbsDefaultAbsorptionTimes) { value in
                            Text("\(String(format: "%.1f", value)) hours").tag(TimeInterval.hours(value))
                        }
                    }

                    let carbsExtraAbsortionTimes: [Double] = [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 5, 6]
                    Picker(
                        selection: $settings.carbsExtraAbsortionTime,
                        label: Text("Extra Absorption Time")
                    ) {
                        ForEach(values: carbsExtraAbsortionTimes) { value in
                            Text("\(String(format: "%.1f", value)) hours").tag(TimeInterval.hours(value))
                        }
                    }

                    let carbsErrorPercentages: [Double] = [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 5, 6, 7, 8, 9, 10]
                    Picker(
                        selection: $settings.carbErrorPercent,
                        label: Text("Allowed Error Percent")
                    ) {
                        ForEach(values: carbsErrorPercentages) { value in
                            Text("\(String(format: "%.1f", value))%").tag(value)
                        }
                    }
                }
                Text("Not all carbs are absorbed within the entered absorption time. \"Extra absorption time\" adds some additional time to allow using those carbs.")
                Text("\"Allowed error percent\" only allows a certain amount of carbs to cary past the extra absorption time.")
            }
            .navigationTitle("Settings")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView().environmentObject(SettingsStore())
    }
}

extension ForEach where Data.Element: Hashable, ID == Data.Element, Content: View {
    init(values: Data, content: @escaping (Data.Element) -> Content) {
        self.init(values, id: \.self, content: content)
    }
}
