//
//  SettingsStore.swift
//  LoopTuner
//
//  Created by Randall Knutson on 6/12/22.
//

import SwiftUI
import Combine

final class SettingsStore: ObservableObject {
    private enum Keys {
        static let insulinDelay = "insulinDelay"
        static let insulinActionDuration = "insulinActionDuration"
        static let insulinPeakActivityTime = "insulinPeakActivityTime"
        static let carbsDelay = "carbsDelay"
        static let carbsDefaultAbsorptionTime = "carbsDefaultAbsorptionTime"
        static let carbsExtraAbsortionTime = "carbsExtraAbsortionTime"
        static let carbErrorPercent = "carbErrorPercent"
    }

    private let cancellable: Cancellable
    private let defaults: UserDefaults

    let objectWillChange = PassthroughSubject<Void, Never>()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        defaults.register(defaults: [
            Keys.insulinDelay: TimeInterval.minutes(10),
            Keys.insulinActionDuration: TimeInterval.hours(6),
            Keys.insulinPeakActivityTime: TimeInterval.minutes(65),
            Keys.carbsDelay: TimeInterval.minutes(15),
            Keys.carbsDefaultAbsorptionTime: TimeInterval.hours(3),
            Keys.carbsExtraAbsortionTime: TimeInterval.hours(2),
            Keys.carbErrorPercent: 2.0,
        ])

        cancellable = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .map { _ in () }
            .subscribe(objectWillChange)
    }

    var insulinDelay: TimeInterval {
        set { defaults.set(newValue, forKey: Keys.insulinDelay) }
        get { defaults.double(forKey: Keys.insulinDelay) }
    }

    var insulinActionDuration: TimeInterval {
        set { defaults.set(newValue, forKey: Keys.insulinActionDuration) }
        get { defaults.double(forKey: Keys.insulinActionDuration) }
    }

    var insulinPeakActivityTime: TimeInterval {
        set { defaults.set(newValue, forKey: Keys.insulinPeakActivityTime) }
        get { defaults.double(forKey: Keys.insulinPeakActivityTime) }
    }

    var carbsDelay: TimeInterval {
        set { defaults.set(newValue, forKey: Keys.carbsDelay) }
        get { defaults.double(forKey: Keys.carbsDelay) }
    }

    var carbsDefaultAbsorptionTime: TimeInterval {
        set { defaults.set(newValue, forKey: Keys.carbsDefaultAbsorptionTime) }
        get { defaults.double(forKey: Keys.carbsDefaultAbsorptionTime) }
    }

    var carbsExtraAbsortionTime: TimeInterval {
        set { defaults.set(newValue, forKey: Keys.carbsExtraAbsortionTime) }
        get { defaults.double(forKey: Keys.carbsExtraAbsortionTime) }
    }

    var carbErrorPercent: Double {
        set { defaults.set(newValue, forKey: Keys.carbErrorPercent) }
        get { defaults.double(forKey: Keys.carbErrorPercent) }
    }
}
