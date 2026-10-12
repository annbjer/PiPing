@preconcurrency import CloudKit
import Foundation
import SettleBellCore

public enum CloudKitSchema {
    public static let recordType = "PiPingAttention"
    public static let occurredAtField = "occurredAt"
    public static let rollingRecordName = "piping.attention.current"
    public static let subscriptionID = "piping.attention.v1"

    public static func makeRecord(for event: AttentionEvent) -> CKRecord {
        let recordID = CKRecord.ID(recordName: rollingRecordName)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        record[occurredAtField] = event.occurredAt as NSDate
        return record
    }

    /// Existence of the historical ID alone is not proof of a safe subscription.
    /// Mismatches require explicit recovery; they are never silently replaced.
    public static func matchesSubscription(_ subscription: CKSubscription) -> Bool {
        guard let query = subscription as? CKQuerySubscription,
              query.subscriptionID == subscriptionID,
              query.recordType == recordType,
              query.predicate.isEqual(NSPredicate(value: true)),
              query.zoneID == nil,
              query.querySubscriptionOptions == [.firesOnRecordCreation, .firesOnRecordUpdate],
              let notification = query.notificationInfo else {
            return false
        }
        return notification.title == AttentionContent.title
            && notification.alertBody == AttentionContent.body
            && notification.soundName == "default"
            // CloudKit may normalize an empty desiredKeys array to nil.
            && (notification.desiredKeys ?? []).isEmpty
            && !notification.shouldBadge
            && !notification.shouldSendContentAvailable
            && !notification.shouldSendMutableContent
            && notification.category == nil
            && notification.collapseIDKey == nil
            && notification.alertLocalizationKey == nil
            && notification.alertLocalizationArgs == nil
            && notification.titleLocalizationKey == nil
            && notification.titleLocalizationArgs == nil
            && notification.subtitle == nil
            && notification.subtitleLocalizationKey == nil
            && notification.subtitleLocalizationArgs == nil
            && notification.alertActionLocalizationKey == nil
            && notification.alertLaunchImage == nil
    }

    public static func makeSubscription() -> CKQuerySubscription {
        let subscription = CKQuerySubscription(
            recordType: recordType,
            predicate: NSPredicate(value: true),
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        let notification = CKSubscription.NotificationInfo()
        notification.title = AttentionContent.title
        notification.alertBody = AttentionContent.body
        notification.soundName = "default"
        notification.desiredKeys = []
        subscription.notificationInfo = notification
        return subscription
    }
}
