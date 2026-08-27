@preconcurrency import CloudKit
import Foundation
import PiPingCore

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
