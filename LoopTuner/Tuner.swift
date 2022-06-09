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
    
    func getCSVData(fileName: String) -> Array<String> {
        guard let filepath = Bundle.main.path(forResource: fileName, ofType: "csv")
            else {
                return []
            }
        do {
            let content = try String(contentsOfFile: filepath, encoding: .utf8)
            let parsedCSV: [String] = content.components(separatedBy: "\n")
            return parsedCSV
        }
        catch {
            print(error)
            return []
        }
    }
    
    func loadBloodGlucose() -> [BloodGlucose] {
        var bloodBlucoseArray: [BloodGlucose] = []
        let csvRows: [String] = getCSVData(fileName: "bloodglucose")
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        for (index, row) in csvRows.enumerated() {
            if (index != 0) {
                let columns = row.components(separatedBy: ",")
                if columns.count == 2 {
                    let bg = Double(columns[0])
                    let startDate = dateFormatter.date(from: columns[1])
                    let csvColumns: BloodGlucose = BloodGlucose.init(startDate: startDate, bg: bg)
                    bloodBlucoseArray.append(csvColumns)
                }
            }
        }
        
        return bloodBlucoseArray
    }
    
    func loadInsulin() -> [InsulinDelivery] {
        var insulinArray: [InsulinDelivery] = []
        let csvRows: [String] = getCSVData(fileName: "insulin")
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        for (index, row) in csvRows.enumerated() {
            if (index != 0) {
                let columns = row.components(separatedBy: ",")
                if columns.count == 4 {
                    let startDate = dateFormatter.date(from: columns[1])
                    let units = Double(columns[0])
                    let insulinType = columns[2]
                    let basalRate = Double(columns[3].split(separator: " ").item(at: 0) ?? "")
                    let csvColumns: InsulinDelivery = InsulinDelivery.init(startDate: startDate, units: units, insulinType: insulinType, basalRate: basalRate)
                    insulinArray.append(csvColumns)
                }
            }
        }
        
        return insulinArray
    }

    func loadCarbs() -> [DietaryCarbohydrates] {
        var carbsArray: [DietaryCarbohydrates] = []
        let csvRows: [String] = getCSVData(fileName: "carbs")
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        for (index, row) in csvRows.enumerated() {
            if (index != 0) {
                let columns = row.components(separatedBy: ",")
                if columns.count == 3 {
                    let startDate = dateFormatter.date(from: columns[1])
                    let carbs = Double(columns[0])
                    let absorptionTime = Int(columns[2])
                    let csvColumns: DietaryCarbohydrates = DietaryCarbohydrates.init(startDate: startDate, carbs: carbs, absorptionTime: absorptionTime)
                    carbsArray.append(csvColumns)
                }
            }
        }
        
        return carbsArray
    }
    
    func getIndex(startDate: TimeInterval, currentDate: TimeInterval) -> Int {
        return Int(currentDate - startDate) / 300
    }

    var body: some View {
        VStack {
            Text("Loop Tuner")
                .padding()
            
            Button(action: {
                Task {
                    let bgs = loadBloodGlucose()
                    let carbs = loadCarbs()
                    let insulins = loadInsulin()
                    
                    let mlManager = MLManager()
                    mlManager.convertHealthKitToMLDataTable(bloodGlucoses: bgs, carbs: carbs, insulinDoses: insulins)
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

fileprivate extension Array {
    func item(at index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
