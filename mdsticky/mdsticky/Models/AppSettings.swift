//
//  AppSettings.swift
//  mdsticky
//
//  Application-wide settings backed by UserDefaults.
//

import Foundation
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published var autoStart: Bool {
        didSet { defaults.set(autoStart, forKey: Keys.autoStart) }
    }

    private struct Keys {
        static let autoStart = "mdsticky.autoStart"
    }

    private init() {
        autoStart = defaults.bool(forKey: Keys.autoStart)
    }
}
