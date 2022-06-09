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
    
    func getInsulin() async -> Void {
        let samples = await queryData(quantityType: .insulinDelivery, numberOfDays: 31)
        let headerString = "units,startDate,insulinType,basal"
        print(headerString)
        var csvString = "\(headerString)\n"
        for sample in samples as? [HKQuantitySample] ?? [] {
            let unit = HKUnit(from: "IU")
            let value = sample.quantity.doubleValue(for: unit)
            let startDate = sample.startDate
            let insulinType = sample.metadata?["com.loopkit.InsulinKit.MetadataKeyInsulinType"] ?? ""
            let basal = sample.metadata?["com.loopkit.InsulinKit.MetadataKeyScheduledBasalRate"] ?? ""
            let dataString = "\(value),\(startDate.ISO8601Format()),\(insulinType),\(basal)"

            print("\(dataString)")
            csvString = csvString.appending("\(dataString)\n")
        }
    }
    
    func getCarbs() async -> Void {
        let samples = await queryData(quantityType: .dietaryCarbohydrates, numberOfDays: 31)
        let headerString = "carbs,startDate,absorptionTime"
        print(headerString)
        var csvString = "\(headerString)\n"
        for sample in samples as? [HKQuantitySample] ?? [] {
            let unit = HKUnit(from: "g")
            let value = sample.quantity.doubleValue(for: unit)
            let startDate = sample.startDate
            let absorptionTime = sample.metadata?["com.loopkit.AbsorptionTime"] ?? ""
            let dataString = "\(value),\(startDate.ISO8601Format()),\(absorptionTime)"

            print("\(dataString)")
            csvString = csvString.appending("\(dataString)\n")
        }
    }
    
    func getBloodGlucose() async -> Void {
        let samples = await queryData(quantityType: .bloodGlucose, numberOfDays: 30)
        let headerString = "bg,startDate"
        print(headerString)
        var csvString = "\(headerString)\n"
        for sample in samples as? [HKQuantitySample] ?? [] {
            let unit = HKUnit(from: "mg/dL")
            let value = sample.quantity.doubleValue(for: unit)
            let startDate = sample.startDate
            let dataString = "\(value),\(startDate.ISO8601Format())"

            print("\(dataString)")
            csvString = csvString.appending("\(dataString)\n")
        }
    }
}
