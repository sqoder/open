//
//  TerminalNotificationService.swift
//  siqi
//
//  Created for siqi Terminal.
//

import Foundation
import UserNotifications

/// Posts Ghostty-requested desktop notifications through the system notification center
public enum TerminalNotificationService {
    private static var authorized = false
    private static var requested = false

    public static func post(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        let deliver = {
            let content = UNMutableNotificationContent()
            content.title = title.isEmpty ? "siqi" : title
            content.body = body
            content.sound = .default
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
        if authorized {
            deliver()
        } else if !requested {
            requested = true
            center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                Task { @MainActor in
                    authorized = granted
                    if granted { deliver() }
                }
            }
        }
    }
}
