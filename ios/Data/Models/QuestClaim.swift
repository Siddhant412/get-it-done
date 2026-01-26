import Foundation
import SwiftData

@Model
final class QuestClaim: Identifiable {
    var id: UUID
    var questID: String
    var weekStart: Date
    var rewardXP: Int
    var claimedAt: Date

    init(
        id: UUID = UUID(),
        questID: String,
        weekStart: Date,
        rewardXP: Int,
        claimedAt: Date = Date()
    ) {
        self.id = id
        self.questID = questID
        self.weekStart = weekStart
        self.rewardXP = rewardXP
        self.claimedAt = claimedAt
    }
}
