import Foundation
import SwiftData

@Model
final class XPBonus: Identifiable {
    var id: UUID
    var source: String
    var detail: String
    var amount: Int
    var weekStart: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        source: String,
        detail: String = "",
        amount: Int,
        weekStart: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.source = source
        self.detail = detail
        self.amount = amount
        self.weekStart = weekStart
        self.createdAt = createdAt
    }
}
