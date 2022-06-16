//
//  Autotuner.swift
//  LoopTuner
//
//  Created by Randall Knutson on 6/5/22.
//

import Foundation

enum TunerError: Error {
    case excessCarbs
    case invalidData
}

struct TuneResults: Identifiable {
    var period: String = "Daily"
    var isf: Double
    var cr: Double
    var basal: Double
    var rmse: Double
    let id = UUID()
}

extension TuneResults {
    var isfString: String {
        String(format: "%.1f", isf)
    }
    var crString: String {
        String(format: "%.1f", cr)
    }
    var basalString: String {
        String(format: "%.2f", Double(Int(basal * 20.0))/20.0)
    }
    var rmseString: String {
        String(format: "%.1f", rmse)
    }
}

class Autotuner: NSObject {
    var settings: SettingsStore
    var intervals: [TreatmentInterval] = []
    var startDate: TimeInterval = 0
    var endDate: TimeInterval = 0
    var intervalsPerHour: Double = 0.0

    let intervalTime: TimeInterval = .minutes(5)
    
    init(_ settings: SettingsStore) {
        self.settings = settings
    }
    
    func getIndex(startDate: TimeInterval, currentDate: TimeInterval) -> Int {
        return Int((currentDate - startDate) / intervalTime)
    }
    
    func getHour(date: Date) -> Int {
        return Calendar.current.component(.hour, from: date)
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
        let insulinModel = ExponentialModel(actionDuration: settings.insulinActionDuration, peakActivityTime: settings.insulinPeakActivityTime, delay: settings.insulinDelay)
        for insulinDose in insulinDoses {
            guard let currentDate = insulinDose.startDate else { continue }
            let units = insulinDose.units ?? 0
            let basalRate = insulinDose.basalRate ?? 0
            // TODO: This only works for 5 minute intervals. For longer intervals we need to check each 5 minute interval to see how much basal was delivered.
            let totalDose = units + basalRate / intervalsPerHour
            let index = getIndex(startDate: startDate, currentDate: currentDate.timeIntervalSince1970)
            let durationIntervalsCount = Int(settings.insulinActionDuration / intervalTime)
            for i in 0..<durationIntervalsCount {
                let offsetIndex = index + i
                if (offsetIndex > 0 && offsetIndex < intervals.count) {
                    let percentAbsorbed = insulinModel.percentEffectRemaining(at: Double(i) * intervalTime) - insulinModel.percentEffectRemaining(at: Double(i + 1) * intervalTime)
                    intervals[offsetIndex].insulin += percentAbsorbed * totalDose
                }
            }
        }
    }

    func markCarbs(carbs: [DietaryCarbohydrates]) {
        for carb in carbs {
            guard let currentDate = carb.startDate else { continue }
            let actionDuration: TimeInterval = TimeInterval(carb.absorptionTime ?? Int(settings.carbsDefaultAbsorptionTime)) + settings.carbsDelay
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
    
    func calcAverageBasal(hour: Int? = nil) -> Double {
        // Calculate average basal rate where zero COB and zero delta BG for several intervals.
        var zeroInsulins: [Double] = []
        let continuityCount = 5
        let tolerance = 3.0
        for (index, interval) in intervals.enumerated() {
            if (
                interval.bg != 0 &&
                intervals.indices.contains(index + continuityCount + 1) &&
                interval.bg < 140 &&
                interval.bg > 80 &&
                (hour == nil || hour == getHour(date: interval.date))
            ) {
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
    
    func tune(bloodGlucoses: [BloodGlucose], carbs: [DietaryCarbohydrates], insulinDoses: [InsulinDelivery]) throws -> [TuneResults] {
        var overallResults = TuneResults(isf: 0.0, cr: 0.0, basal: 0.0, rmse: 100.0)
        var hourlyResults: [TuneResults] = []
        intervalsPerHour = .hours(1) / intervalTime

        guard let startDate = bloodGlucoses.map({ $0.startDate?.timeIntervalSince1970 ?? Double(MAXINTERP) }).min() else { throw TunerError.invalidData }
        self.startDate = startDate
        guard let endDate = bloodGlucoses.map ({ $0.startDate?.timeIntervalSince1970 ?? 0}).max() else { throw TunerError.invalidData }
        self.endDate = endDate
        let intervalCount: Int = Int((endDate - startDate) / intervalTime)
        
        // Initialize array of intervals. This serves as all the possible intervals we are going to check.
        for i in 0...intervalCount {
            intervals.append(TreatmentInterval(date: Date(timeIntervalSince1970: startDate + Double(i) * intervalTime)))
        }
        
        if (settings.hourly) {
            for i in 0...23 {
                hourlyResults.append(TuneResults(period: String(i), isf: 0.0, cr: 0.0, basal: 0.0, rmse: 100.0))
            }
        }
        
        fillBG(bloodGlucoses: bloodGlucoses)

        fillInsulin(insulinDoses: insulinDoses)

        markCarbs(carbs: carbs)

        let overallBasal = calcAverageBasal()
//        print("Basal: \(averageBasal)")
        
        for hour in 0..<hourlyResults.count {
            hourlyResults[hour].basal = calcAverageBasal(hour: hour)
        }

        for hour in 0..<hourlyResults.count {
            if (hourlyResults[hour].basal == 0.0) {
                if (hour > 0) {
                    hourlyResults[hour].basal = hourlyResults[hour - 1].basal
                }
                else {
                    hourlyResults[hour].basal = overallBasal
                }
            }
        }

        // Try various combinations of ISF and CRs to find the best fit.
        var possibleISFs = Array(stride(from: 60.0, to: 190.0, by: 10.0))
        var possibleCRs = Array(stride(from: 9.0, to: 12.0, by: 1.0))
        let sortedCarbs = carbs.sorted(by: { $0.startDate! < $1.startDate! })
        for possibleISF in possibleISFs {
            for possibleCR in possibleCRs {
                do {
                    let rmse = try calculateExpectedBG(intervals: intervals, carbs: sortedCarbs, potentialResults: TuneResults(isf: possibleISF, cr: possibleCR, basal: overallBasal, rmse: 100.0))
                    if (rmse < overallResults.rmse) {
                        overallResults = TuneResults(isf: possibleISF, cr: possibleCR, basal: overallBasal, rmse: rmse)
                    }
                }
                catch {
//                    print("\(possibleISF),\(possibleCR),\(error)")
                }
                for hour in 0..<hourlyResults.count {
                    do {
                        let hourlyRmse = try calculateExpectedBG(intervals: intervals, carbs: sortedCarbs, potentialResults: TuneResults(isf: possibleISF, cr: possibleCR, basal: hourlyResults[hour].basal, rmse: 100.0), hour: hour)
                        if (hourlyRmse < hourlyResults[hour].rmse) {
                            hourlyResults[hour].isf = possibleISF
                            hourlyResults[hour].cr = possibleCR
                            hourlyResults[hour].rmse = hourlyRmse
                        }
                    }
                    catch {
                        
                    }
                }
            }
        }

        possibleISFs = Array(stride(from: (overallResults.isf - 10.0), to: (overallResults.isf + 10.0), by: 1.0))
        possibleCRs = Array(stride(from: (overallResults.cr - 1.0), to: (overallResults.cr + 1.0), by: 0.1))
        for possibleISF in possibleISFs {
            for possibleCR in possibleCRs {
                do {
                    let rmse = try calculateExpectedBG(intervals: intervals, carbs: sortedCarbs, potentialResults: TuneResults(isf: possibleISF, cr: possibleCR, basal: overallBasal, rmse: 100.0))
                    if (rmse < overallResults.rmse) {
                        overallResults = TuneResults(isf: possibleISF, cr: possibleCR, basal: overallBasal, rmse: rmse)
                    }
                }
                catch {
//                    print("\(possibleISF),\(possibleCR),\(error)")
                }
            }
        }
        
//        for hour in 0..<hourlyResults.count {
//            possibleISFs = Array(stride(from: (hourlyResults[hour].isf - 10.0), to: (hourlyResults[hour].isf + 10.0), by: 1.0))
//            possibleCRs = Array(stride(from: (hourlyResults[hour].cr - 1.0), to: (hourlyResults[hour].cr + 1.0), by: 0.1))
//            for possibleISF in possibleISFs {
//                for possibleCR in possibleCRs {
//                    do {
//                        let rmse = try calculateExpectedBG(intervals: intervals, carbs: sortedCarbs, potentialResults: TuneResults(isf: possibleISF, cr: possibleCR, basal: hourlyResults[hour].basal, rmse: 100.0))
//                        if (rmse < hourlyResults[hour].rmse) {
//                            hourlyResults[hour] = TuneResults(period: hourlyResults[hour].period, isf: possibleISF, cr: possibleCR, basal: hourlyResults[hour].basal, rmse: rmse)
//                        }
//                    }
//                    catch {
//    //                    print("\(possibleISF),\(possibleCR),\(error)")
//                    }
//                }
//            }
//        }

        var results = [overallResults]
        results.append(contentsOf: hourlyResults)
        
        return results
    }
    
    func calculateExpectedBG(intervals inter: [TreatmentInterval], carbs: [DietaryCarbohydrates], potentialResults: TuneResults, hour: Int? = nil) throws -> Double {
        var errors: [Double] = []
        var intervals = inter
        let startDate = intervals[0].date.timeIntervalSince1970
        var totalCarbs = 0.0
        let basal = potentialResults.basal / intervalsPerHour

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
                    let carbsExpire = activeCarbs[0].startDate!.timeIntervalSince1970 + Double(activeCarbs[0].absorptionTime ?? 0) + settings.carbsExtraAbsortionTime
                    if (carbsExpire < interval.date.timeIntervalSince1970) {
                        excessCarbs += activeCarbs[0].carbs ?? 0.0
                        activeCarbs.removeFirst()
                    }
                }
                let deltabg = intervals[index + 1].bg - interval.bg
                let bolus = (interval.insulin - basal)
                if (bolus > 0) {
                    let carbDeltaBG = deltabg + bolus * potentialResults.isf
                    var extraCarbs = carbDeltaBG / potentialResults.cr
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
                let expectedDeltaBG = carbs * potentialResults.cr - bolus * potentialResults.isf
                if (hour == nil || hour == getHour(date: interval.date)) {
                    errors.append(pow(deltabg - expectedDeltaBG, 2))
                }
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
