//
//  StickyNote.swift
//  mdsticky
//
//  Sticky note model persisted with SwiftData.
//

import Foundation
import SwiftData

@Model
final class StickyNote {
    @Attribute(.unique) var id: UUID
    var title: String
    var contentFileName: String
    var colorHex: String
    var positionX: Double
    var positionY: Double
    var width: Double
    var height: Double
    var isPinned: Bool
    var isVisible: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        contentFileName: String,
        colorHex: String = "#FFEB3B",
        positionX: Double = 200,
        positionY: Double = 200,
        width: Double = 300,
        height: Double = 220,
        isPinned: Bool = false,
        isVisible: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.contentFileName = contentFileName
        self.colorHex = colorHex
        self.positionX = positionX
        self.positionY = positionY
        self.width = width
        self.height = height
        self.isPinned = isPinned
        self.isVisible = isVisible
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func touch() {
        updatedAt = Date()
    }
}
