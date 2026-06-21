//
//  AutoStartService.swift
//  mdsticky
//
//  Registers the app as a login item and restores visible notes on launch.
//

import Foundation
import ServiceManagement

@MainActor
final class AutoStartService {
    static let shared = AutoStartService()

    private let serviceIdentifier = "charleypeng.mdsticky.launcher"

    private init() {}

    func setEnabled(_ enabled: Bool) {
        let service = SMAppService.loginItem(identifier: serviceIdentifier)
        do {
            if enabled {
                if service.status == .notRegistered {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
        } catch {
            print("Login item registration failed: \(error)")
        }
    }

    var isEnabled: Bool {
        let service = SMAppService.loginItem(identifier: serviceIdentifier)
        return service.status == .enabled
    }
}
