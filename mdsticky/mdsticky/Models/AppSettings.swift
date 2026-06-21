//
//  AppSettings.swift
//  mdsticky
//
//  Application-wide settings backed by UserDefaults.
//

import Foundation
import Combine
import SwiftUI

enum ColorSchemeMode: String, CaseIterable {
    case system
    case light
    case dark

    var resolved: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
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

    func tr(_ key: String) -> String {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}

func tr(_ key: String) -> String {
    AppSettings.shared.tr(key)
}
