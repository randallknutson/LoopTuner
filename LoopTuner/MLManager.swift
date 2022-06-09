//
//  MLManager.swift
//  LoopTuner
//
//  Created by Randall Knutson on 6/5/22.
//

import Foundation
//import CreateML
import CoreML

class MLManager: NSObject {
    var intervals: [TreatmentInterval] = []
    
    let intervalTime: TimeInterval = .minutes(5)
    let insulinDelay: TimeInterval = .minutes(10)
    let insulinActionDuration: TimeInterval = .minutes(360)
    let insulinPeakActivityTime: TimeInterval = .minutes(55)
    let carbsDelay: TimeInterval = .minutes(15)
    let carbsDefaultAbsorptionTime: TimeInterval = .hours(3)
    let carbsPeakPercent = 0.49
    
    func loadModel() async {
        guard let filepath = Bundle.main.path(forResource: "0.077", ofType: "mlmodel")
            else {
                return
            }

        guard let url = URL(string: filepath) else { return }
        
        let model = try? await MLModel.load(contentsOf: url)
//        let result = try? model?.prediction(carbs: 1.0, insulin: 0)
//        print (result)
    }
    
    func getIndex(startDate: TimeInterval, currentDate: TimeInterval) -> Int {
        return Int((currentDate - startDate) / intervalTime)
    }

    func convertHealthKitToMLDataTable(bloodGlucoses: [BloodGlucose], carbs: [DietaryCarbohydrates], insulinDoses: [InsulinDelivery]) {
        let intervalsPerHour = .hours(1) / intervalTime

        guard let startDate = bloodGlucoses.map({ $0.startDate?.timeIntervalSince1970 ?? Double(MAXINTERP) }).min() else { return }
        guard let endDate = bloodGlucoses.map ({ $0.startDate?.timeIntervalSince1970 ?? 0}).max() else { return }
        let intervalCount: Int = Int((endDate - startDate) / intervalTime)
        
        // Initialize array
        for i in 0...intervalCount {
            intervals.append(TreatmentInterval(date: Date(timeIntervalSince1970: startDate + Double(i) * intervalTime)))
        }
        
        // Fill known blood glucose values
        for bloodGlucose in bloodGlucoses {
            guard let currentDate = bloodGlucose.startDate, let bg = bloodGlucose.bg else { continue }
            let index = getIndex(startDate: startDate, currentDate: currentDate.timeIntervalSince1970)
            if (index > 0 && index < intervals.count && intervals[index].bg == 0) {
                intervals[index].bg = bg
            }
        }

        // Fill insulin values
        let insulinModel = ExponentialModel(actionDuration: insulinActionDuration, peakActivityTime: insulinPeakActivityTime, delay: insulinDelay)
        for insulinDose in insulinDoses {
            guard let currentDate = insulinDose.startDate else { continue }
            let units = insulinDose.units ?? 0
            let basalRate = insulinDose.basalRate ?? 0
            // TODO: This only works for 5 minute intervals. For longer intervals we need to check each 5 minute interval to see how much basal was delivered.
            let totalDose = units + basalRate / intervalsPerHour
            let index = getIndex(startDate: startDate, currentDate: currentDate.timeIntervalSince1970)
            let durationIntervalsCount = Int(insulinActionDuration / intervalTime)
            for i in 0..<durationIntervalsCount {
                let offsetIndex = index + i
                if (offsetIndex > 0 && offsetIndex < intervals.count) {
                    let percentAbsorbed = insulinModel.percentEffectRemaining(at: Double(i) * intervalTime) - insulinModel.percentEffectRemaining(at: Double(i + 1) * intervalTime)
                    intervals[offsetIndex].insulin += percentAbsorbed * totalDose
                }
            }
        }

        // Mark each interval with whether or not it has carbs.
        for carb in carbs {
            guard let currentDate = carb.startDate else { continue }
            let actionDuration: TimeInterval = TimeInterval(carb.absorptionTime ?? Int(carbsDefaultAbsorptionTime)) + carbsDelay + .hours(1)
            let index = getIndex(startDate: startDate, currentDate: currentDate.timeIntervalSince1970)
            let durationIntervalsCount = Int(actionDuration / intervalTime)
            for i in 0..<durationIntervalsCount {
                let offsetIndex = index + i
                if (offsetIndex > 0 && offsetIndex < intervals.count) {
                    intervals[offsetIndex].hasCarbs = true
                }
            }
        }

        // Calculate average basal rate where zero COB and zero delta BG
        var zeroInsulins: [Double] = []
        let continuityCount = 5
        let tolerance = 3.0
        for (index, interval) in intervals.enumerated() {
            if (interval.bg != 0 && intervals.indices.contains(index + continuityCount + 1) && interval.bg < 120 && interval.bg > 100) {
                var isContinuous = true
                if (interval.hasCarbs) {
                    continue
                }
                for i in 0...continuityCount {
                    let deltabg = intervals[index + i + 1].bg - intervals[index + i].bg
                    if (abs(deltabg) > tolerance) {
                        isContinuous = false
                    }
                }
                if (isContinuous) {
                    zeroInsulins.append(interval.insulin)
//                    print("\(interval.bg),\(interval.insulin)")
                }
            }
        }
        let averageBasal = zeroInsulins.average * intervalsPerHour

        // Fill carb values
        let baseCarbsPercent = 1.0 // Should add up to 1.0
        let insulinCarbsPercent = 0.0
        let bgCarbsPercent = 0.0
        for carb in carbs {
            guard let currentDate = carb.startDate, let totalCarbs = carb.carbs else { continue }
            var myCarbs = 0.0
            let actionDuration: TimeInterval = TimeInterval(carb.absorptionTime ?? Int(carbsDefaultAbsorptionTime)) + carbsDelay
            let index = getIndex(startDate: startDate, currentDate: currentDate.timeIntervalSince1970)
            let durationIntervalsCount = Int(actionDuration / intervalTime)
            
            // First, calculate the min bg and total extra insulin during this duration.
            var durationMinBG = 1000.0
            var durationTotalDeltaBG = 0.0
            var durationMinInsulin = 0.0
            var durationTotalExtraInsulin = 0.0
            for i in 0..<durationIntervalsCount {
                let offsetIndex = index + i
                if (offsetIndex > 0 && offsetIndex < intervals.count) {
                    if (intervals[offsetIndex].bg < durationMinBG) {
                        durationMinBG = intervals[offsetIndex].bg
                    }
                    if (intervals[offsetIndex].insulin < durationMinInsulin) {
                        durationMinInsulin = intervals[offsetIndex].insulin
                    }
                }
            }
            for i in 0..<durationIntervalsCount {
                let offsetIndex = index + i
                if (offsetIndex > 0 && offsetIndex < intervals.count) {
                    durationTotalDeltaBG += intervals[index + 1].bg - intervals[offsetIndex].bg
                    durationTotalExtraInsulin += intervals[offsetIndex].insulin - durationMinInsulin
                }
            }

            let peakActivityTime: TimeInterval = actionDuration * carbsPeakPercent
            let carbModel = ExponentialModel(actionDuration: actionDuration, peakActivityTime: peakActivityTime, delay: carbsDelay)
            for i in 0..<durationIntervalsCount {
                let offsetIndex = index + i
                if (offsetIndex > 0 && offsetIndex < intervals.count && totalCarbs != 0) {
                    let interval = intervals[offsetIndex]
                    let percentAbsorbed = carbModel.percentEffectRemaining(at: Double(i) * intervalTime) - carbModel.percentEffectRemaining(at: Double(i + 1) * intervalTime)
//                    intervals[offsetIndex].carbs += percentAbsorbed * totalCarbs
                    let deltabg = intervals[index + 1].bg - interval.bg
//                    let baseCarbs = totalCarbs * baseCarbsPercent / Double(durationIntervalsCount)
                    let baseCarbs = totalCarbs * baseCarbsPercent * percentAbsorbed
                    let insulinCarbs = totalCarbs * insulinCarbsPercent * ((interval.insulin - durationMinInsulin) / durationTotalExtraInsulin)
                    let bgCarbs = totalCarbs * bgCarbsPercent * (deltabg / abs(durationTotalDeltaBG))
                    intervals[offsetIndex].carbs += baseCarbs + insulinCarbs + bgCarbs
                    myCarbs += baseCarbs + insulinCarbs + bgCarbs
                }
            }
//            print("TOTAL", totalCarbs, myCarbs)
        }

        let carbRatio = 10.0
        let insulinSensitivityFactor = 100.0
        print("deltabg,bg,insulin,carbs")
        for (index, interval) in intervals.enumerated() {
            if (interval.bg != 0 && intervals.indices.contains(index + 1) && intervals[index + 1].bg != 0) {
                let deltabg = intervals[index + 1].bg - interval.bg
                let carbs = interval.carbs
                let insulin = interval.insulin
                let expectedDeltaBG = carbs * carbRatio - insulin * insulinSensitivityFactor
                print("\(deltabg),\(Double(round(10 * expectedDeltaBG) / 10)),\(interval.bg),\(insulin),\(carbs)")
            }
        }

    }
    
//    func doML(data: DataFrame) {
//        let data = try MLDataTable(contentsOf: URL(fileURLWithPath: "/Users/twostraws/Desktop/players.json"))
//        let (trainingData, testingData) = data.randomSplit(by: 0.8)
//        let playerPricer = try MLLinearRegressor(trainingData: trainingData, targetColumn: "value")
//        let evaluationMetrics = playerPricer.evaluation(on: testingData)
//        print(evaluationMetrics.rootMeanSquaredError)
//        print(evaluationMetrics.maximumError)
//    }
}

extension Array where Element: BinaryFloatingPoint {

    /// The average value of all the items in the array
    var average: Double {
        if self.isEmpty {
            return 0.0
        } else {
            let sum = self.reduce(0, +)
            return Double(sum) / Double(self.count)
        }
    }

}
