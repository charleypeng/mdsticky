//
//  AppSettings.swift
//  mdsticky
//
//  Application-wide settings backed by UserDefaults.
//

import Foundation
import Combine

enum ColorSchemeMode: String, CaseIterable {
    case system
    case light
    case dark
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published var autoStart: Bool {
        didSet { defaults.set(autoStart, forKey: Keys.autoStart) }
    }

    @Published var language: String {
        didSet { defaults.set(language, forKey: Keys.language) }
    }

    @Published var colorSchemeMode: ColorSchemeMode {
        didSet { defaults.set(colorSchemeMode.rawValue, forKey: Keys.colorSchemeMode) }
    }

    private struct Keys {
        static let autoStart = "mdsticky.autoStart"
        static let language = "mdsticky.language"
        static let colorSchemeMode = "mdsticky.colorSchemeMode"
    }

    private init() {
        autoStart = defaults.bool(forKey: Keys.autoStart)
        language = defaults.string(forKey: Keys.language) ?? "zh-Hans"
        if let raw = defaults.string(forKey: Keys.colorSchemeMode),
           let mode = ColorSchemeMode(rawValue: raw) {
            colorSchemeMode = mode
        } else {
            colorSchemeMode = .system
        }
    }
}
