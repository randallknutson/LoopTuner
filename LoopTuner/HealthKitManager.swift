//
//  HealthKitManager.swift
//  LoopTuner
//
//  Created by Randall Knutson on 5/16/22.
//

import Foundation
import HealthKit

struct InsulinDelivery {
    var startDate: Date?
    var units: Double?
    var insulinType: String?
    var basalRate: Double?
}

struct DietaryCarbohydrates {
    var startDate: Date?
    var carbs: Double?
    var absorptionTime: Int?
}

struct BloodGlucose {
    var startDate: Date?
    var bg: Double?
}

struct TreatmentInterval {
    var date: Date
    var insulin: Double = 0
    var carbs: Double = 0
    var deltabg: Double = 0
    var bg: Double = 0
    var hasCarbs: Bool = false
    var carbDose: [DietaryCarbohydrates] = []
}

class HealthKitManager: NSObject {
    
    let healthStore = HKHealthStore()
    
    // Request authorization to access Healthkit.
    func requestAuthorization() async -> Bool {

        // The quantity type to write to the health store.
//        let typesToShare: Set = []

        // The quantity types to read from the health store.
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!,
            HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
            HKQuantityType.quantityType(forIdentifier: .insulinDelivery)!,
            HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
        ]

        // Request authorization for those quantity types
        let res: ()? = try? await healthStore.requestAuthorization(toShare: [], read: typesToRead)

        guard res != nil else {
            return false
        }

        return true

    }
    
    func queryData(quantityType: HKQuantityTypeIdentifier, numberOfDays: Int) async -> [HKSample] {
        guard HKHealthStore.isHealthDataAvailable() else {
          return []
        }
        
        guard let sampleType:HKQuantityType  = HKQuantityType.quantityType(forIdentifier: quantityType) else { return [] }
                

        //1. Use HKQuery to load the most recent samples.
        let previousDays = HKQuery.predicateForSamples(withStart: Calendar.current.date(byAdding: .day, value: -numberOfDays, to: Date()),
                                                              end: Date(),
                                                              options: .strictEndDate)
            
        let samples = try! await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            healthStore.execute(HKSampleQuery(
                sampleType: sampleType,
                predicate: previousDays,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [.init(keyPath: \HKSample.startDate, ascending: false)],
                resultsHandler: { query, samples, error in
                    if let hasError = error {
                        continuation.resume(throwing: hasError)
                        return
                    }

                    guard let samples = samples else {
                        fatalError("*** Invalid State: This can only fail if there was an error. ***")
                    }

                    continuation.resume(returning: samples)
            }))
        }
        
        return samples
    }
    
    func getInsulin() async -> [InsulinDelivery] {
        var insulins: [InsulinDelivery] = []
        let samples = await queryData(quantityType: .insulinDelivery, numberOfDays: 31)
        let headerString = "units,startDate,insulinType,basal"
        print(headerString)
//        var csvString = "\(headerString)\n"
        for sample in samples as? [HKQuantitySample] ?? [] {
            let unit = HKUnit(from: "IU")
            let value = sample.quantity.doubleValue(for: unit)
            let startDate = sample.startDate
            let insulinType = (sample.metadata?["com.loopkit.InsulinKit.MetadataKeyInsulinType"] ?? "") as! String
            let basalRate = Double(((sample.metadata?["com.loopkit.InsulinKit.MetadataKeyScheduledBasalRate"] ?? "") as! String).split(separator: " ").item(at: 0) ?? "")
            insulins.append(InsulinDelivery(startDate: startDate, units: value, insulinType: insulinType, basalRate: basalRate))
//            let dataString = "\(value),\(startDate.ISO8601Format()),\(insulinType),\(basal)"

//            print("\(dataString)")
//            csvString = csvString.appending("\(dataString)\n")
        }
        return insulins
    }
    
    func getCarbs() async -> [DietaryCarbohydrates] {
        var carbs: [DietaryCarbohydrates] = []
        let samples = await queryData(quantityType: .dietaryCarbohydrates, numberOfDays: 31)
        let headerString = "carbs,startDate,absorptionTime"
        print(headerString)
//        var csvString = "\(headerString)\n"
        for sample in samples as? [HKQuantitySample] ?? [] {
            let unit = HKUnit(from: "g")
            let value = sample.quantity.doubleValue(for: unit)
            let startDate = sample.startDate
            let absorptionTime = Int((sample.metadata?["com.loopkit.AbsorptionTime"] ?? "") as! String) ?? 0
            carbs.append(DietaryCarbohydrates(startDate: startDate, carbs: value, absorptionTime: absorptionTime))
//            let dataString = "\(value),\(startDate.ISO8601Format()),\(absorptionTime)"

//            print("\(dataString)")
//            csvString = csvString.appending("\(dataString)\n")
        }
        return carbs
    }
    
    func getBloodGlucose() async -> [BloodGlucose] {
        var bg: [BloodGlucose] = []
        let samples = await queryData(quantityType: .bloodGlucose, numberOfDays: 30)
        let headerString = "bg,startDate"
        print(headerString)
        var csvString = "\(headerString)\n"
        for sample in samples as? [HKQuantitySample] ?? [] {
            let unit = HKUnit(from: "mg/dL")
            let value = sample.quantity.doubleValue(for: unit)
            let startDate = sample.startDate
            bg.append(BloodGlucose(startDate: startDate, bg: value))
//            let dataString = "\(value),\(startDate.ISO8601Format())"

//            print("\(dataString)")
//            csvString = csvString.appending("\(dataString)\n")
        }
        return bg
    }
    
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
    
    func loadBloodGlucoseCSV() -> [BloodGlucose] {
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
    
    func loadInsulinCSV() -> [InsulinDelivery] {
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

    func loadCarbsCSV() -> [DietaryCarbohydrates] {
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
}

fileprivate extension Array {
    func item(at index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
