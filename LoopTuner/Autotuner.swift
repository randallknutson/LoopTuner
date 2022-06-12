//
//  Autotuner.swift
//  LoopTuner
//
//  Created by Randall Knutson on 6/5/22.
//

import Foundation

enum TunerError: Error {
    case excessCarbs
}

class Autotuner: NSObject {
    var intervals: [TreatmentInterval] = []
    var startDate: TimeInterval = 0
    var endDate: TimeInterval = 0
    var intervalsPerHour: Double = 0.0

    let intervalTime: TimeInterval = .minutes(5)
    let insulinDelay: TimeInterval = .minutes(10)
    let insulinActionDuration: TimeInterval = .minutes(360)
    let insulinPeakActivityTime: TimeInterval = .minutes(55)
    let carbsDelay: TimeInterval = .minutes(15)
    let carbsDefaultAbsorptionTime: TimeInterval = .hours(3)
    
    func getIndex(startDate: TimeInterval, currentDate: TimeInterval) -> Int {
        return Int((currentDate - startDate) / intervalTime)
    }
    
    func fillBG(bloodGlucoses: [BloodGlucose]) {
        // Fill known blood glucose values.
        for bloodGlucose in bloodGlucoses {
            guard let currentDate = bloodGlucose.startDate, let bg = bloodGlucose.bg else { continue }
            let index = getIndex(startDate: startDate, currentDate: currentDate.timeIntervalSince1970)
            if (index > 0 && index < intervals.count && intervals[index].bg == 0) {
                intervals[index].bg = bg
            }
        }
    }
    
    func fillInsulin(insulinDoses: [InsulinDelivery]) {
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
    }

    func marCarbs(carbs: [DietaryCarbohydrates]) {
        for carb in carbs {
            guard let currentDate = carb.startDate else { continue }
            let actionDuration: TimeInterval = TimeInterval(carb.absorptionTime ?? Int(carbsDefaultAbsorptionTime)) + carbsDelay
            let index = getIndex(startDate: startDate, currentDate: currentDate.timeIntervalSince1970)
            let durationIntervalsCount = Int(actionDuration / intervalTime)
            for i in 0..<durationIntervalsCount {
                let offsetIndex = index + i
                if (offsetIndex > 0 && offsetIndex < intervals.count) {
                    intervals[offsetIndex].hasCarbs = true
                }
            }
        }
    }
    
    func calcAverageBasal() -> Double {
        // Calculate average basal rate where zero COB and zero delta BG for several intervals.
        var zeroInsulins: [Double] = []
        let continuityCount = 5
        let tolerance = 3.0
        for (index, interval) in intervals.enumerated() {
            if (interval.bg != 0 && intervals.indices.contains(index + continuityCount + 1) && interval.bg < 140 && interval.bg > 80) {
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
                }
            }
        }
        // Basal rate translates to IOB/2
        let averageBasal = zeroInsulins.average * intervalsPerHour / 2
        return averageBasal
    }
    
    func convertHealthKitToMLDataTable(bloodGlucoses: [BloodGlucose], carbs: [DietaryCarbohydrates], insulinDoses: [InsulinDelivery]) {
        intervalsPerHour = .hours(1) / intervalTime

        guard let startDate = bloodGlucoses.map({ $0.startDate?.timeIntervalSince1970 ?? Double(MAXINTERP) }).min() else { return }
        self.startDate = startDate
        guard let endDate = bloodGlucoses.map ({ $0.startDate?.timeIntervalSince1970 ?? 0}).max() else { return }
        self.endDate = endDate
        let intervalCount: Int = Int((endDate - startDate) / intervalTime)
        
        // Initialize array of intervals. This serves as all the possible intervals we are going to check.
        for i in 0...intervalCount {
            intervals.append(TreatmentInterval(date: Date(timeIntervalSince1970: startDate + Double(i) * intervalTime)))
        }
        
        fillBG(bloodGlucoses: bloodGlucoses)

        fillInsulin(insulinDoses: insulinDoses)

        marCarbs(carbs: carbs)

        let averageBasal = calcAverageBasal()
        print("Basal: \(averageBasal)")

        // Try various combinations of ISF and CRs to find the best fit.
        var possibleISFs = Array(stride(from: 60.0, to: 190.0, by: 10.0))
        var possibleCRs = Array(stride(from: 9.0, to: 12.0, by: 1.0))
        let sortedCarbs = carbs.sorted(by: { $0.startDate! < $1.startDate! })
        var bestRMSE = 50.0
        var bestISF = 0.0
        var bestCR = 0.0
        var bestBasal = 0.0
        for possibleISF in possibleISFs {
            for possibleCR in possibleCRs {
                do {
                    let rmse = try calculateExpectedBG(intervals: intervals, carbs: sortedCarbs, ISF: possibleISF, CR: possibleCR, basal: averageBasal/intervalsPerHour)
                    if (rmse < bestRMSE) {
                        bestISF = possibleISF
                        bestCR = possibleCR
                        bestBasal = averageBasal
                        bestRMSE = rmse
                    }
                }
                catch {
//                    print("\(possibleISF),\(possibleCR),\(error)")
                }
            }
        }

        possibleISFs = Array(stride(from: (bestISF - 10.0), to: (bestISF + 10.0), by: 1.0))
        possibleCRs = Array(stride(from: (bestCR - 1.0), to: (bestCR + 1.0), by: 0.1))
        for possibleISF in possibleISFs {
            for possibleCR in possibleCRs {
                do {
                    let rmse = try calculateExpectedBG(intervals: intervals, carbs: sortedCarbs, ISF: possibleISF, CR: possibleCR, basal: averageBasal/intervalsPerHour)
                    if (rmse < bestRMSE) {
                        bestISF = possibleISF
                        bestCR = possibleCR
                        bestBasal = averageBasal
                        bestRMSE = rmse
                    }
                }
                catch {
//                    print("\(possibleISF),\(possibleCR),\(error)")
                }
            }
        }

        print("ISF=\(bestISF),CR=\(bestCR),Basal=\(bestBasal),RMSE=\(bestRMSE)")
    }
    
    func calculateExpectedBG(intervals inter: [TreatmentInterval], carbs: [DietaryCarbohydrates], ISF: Double, CR: Double, basal: Double) throws -> Double {
        var errors: [Double] = []
        var intervals = inter
        let startDate = intervals[0].date.timeIntervalSince1970
        var totalCarbs = 0.0

        // Assign carb entries to intervals so we know when to find them.
        for carb in carbs {
            guard let currentDate = carb.startDate else { continue }
            totalCarbs += carb.carbs ?? 0.0
            let index = getIndex(startDate: startDate, currentDate: currentDate.timeIntervalSince1970)
            if (intervals.indices.contains(index)) {
                intervals[index].carbDose.append(carb)
            }
        }
        
        // Calculate how much blood sugar rise is associated with carbs and remove from remaining carbs.
        var activeCarbs: [DietaryCarbohydrates] = []
        var excessCarbs = 0.0
        for (index, interval) in intervals.enumerated() {
            var carbs: Double = 0
            if (interval.bg != 0 && intervals.indices.contains(index + 1) && intervals[index + 1].bg != 0) {
                if (interval.carbDose.count > 0) {
                    activeCarbs.append(contentsOf: interval.carbDose)
                }
                if (activeCarbs.count > 0) {
                    let carbsExpire = activeCarbs[0].startDate!.timeIntervalSince1970 + Double(activeCarbs[0].absorptionTime ?? 0) + .hours(2)
                    if (carbsExpire < interval.date.timeIntervalSince1970) {
                        excessCarbs += activeCarbs[0].carbs ?? 0.0
                        activeCarbs.removeFirst()
                    }
                }
                let deltabg = intervals[index + 1].bg - interval.bg
                let bolus = (interval.insulin - basal)
                if (bolus > 0) {
                    let carbDeltaBG = deltabg + bolus * ISF
                    var extraCarbs = carbDeltaBG / CR
                    while extraCarbs > 0 && activeCarbs.count > 0 {
                        if (extraCarbs < activeCarbs[0].carbs ?? 0) {
                            carbs += extraCarbs
                            activeCarbs[0].carbs! -= extraCarbs
                            extraCarbs = 0
                        }
                        else {
                            extraCarbs -= activeCarbs[0].carbs ?? 0
                            carbs += activeCarbs[0].carbs ?? 0
                            activeCarbs.removeFirst()
                        }
                    }
                }
                let expectedDeltaBG = carbs * CR - bolus * ISF
                errors.append(pow(deltabg - expectedDeltaBG, 2))
            }
        }
        if (excessCarbs / totalCarbs > 0.02) {
            throw TunerError.excessCarbs
        }
        return sqrt(errors.average)
    }
}

fileprivate extension Array where Element: BinaryFloatingPoint {

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
