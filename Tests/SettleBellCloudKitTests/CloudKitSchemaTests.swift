@preconcurrency import CloudKit
import Foundation
import SettleBellCore
import Testing
@testable import SettleBellCloudKit

@Suite("CloudKit safe schema")
struct CloudKitSchemaTests {
    @Test("records contain only the allowed timestamp field")
    func safeRecordFields() {
        let event = AttentionEvent(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let record = CloudKitSchema.makeRecord(for: event)

        #expect(record.recordType == "PiPingAttention")
        #expect(record.recordID.recordName == CloudKitSchema.rollingRecordName)
        #expect(record.allKeys() == ["occurredAt"])
        #expect(record["occurredAt"] != nil)
    }

    @Test("subscription uses fixed copy, default sound, and no desired record fields")
    func safeSubscription() {
        let subscription = CloudKitSchema.makeSubscription()
        let notification = subscription.notificationInfo

        #expect(subscription.subscriptionID == "piping.attention.v1")
        #expect(subscription.querySubscriptionOptions.contains(.firesOnRecordCreation))
        #expect(subscription.querySubscriptionOptions.contains(.firesOnRecordUpdate))
        #expect(notification?.title == AttentionContent.title)
        #expect(notification?.alertBody == AttentionContent.body)
        #expect(notification?.soundName == "default")
        #expect(notification?.desiredKeys == [])
        #expect(notification?.shouldSendContentAvailable == false)
        #expect(notification?.category == nil)
        #expect(CloudKitSchema.matchesSubscription(subscription))
    }

    @Test("nil and empty desired keys both request no fields")
    func normalizedEmptyKeys() {
        let subscription = CloudKitSchema.makeSubscription()
        let notification = subscription.notificationInfo!
        notification.desiredKeys = nil
        subscription.notificationInfo = notification
        #expect(CloudKitSchema.matchesSubscription(subscription))
    }

    @Test("existing subscription must match every fixed-schema boundary", arguments: subscriptionMismatchCases)
    func rejectsMismatch(_ change: String) {
        #expect(!CloudKitSchema.matchesSubscription(mismatchedSubscription(change)))
    }
}

let subscriptionMismatchCases = [
    "type", "id", "record", "options", "predicate", "zone", "notification",
    "title", "body", "sound", "keys", "background", "mutable", "badge",
    "category", "collapse", "alertLocalization", "alertArgs", "titleLocalization",
    "titleArgs", "subtitle", "subtitleLocalization", "subtitleArgs", "action", "image",
]

func mismatchedSubscription(_ change: String) -> CKSubscription {
    if change == "type" {
        return CKDatabaseSubscription(subscriptionID: CloudKitSchema.subscriptionID)
    }
    if ["id", "record", "options", "predicate"].contains(change) {
        let subscription = CKQuerySubscription(
            recordType: change == "record" ? "OtherRecord" : CloudKitSchema.recordType,
            predicate: NSPredicate(value: change != "predicate"),
            subscriptionID: change == "id" ? "other.id" : CloudKitSchema.subscriptionID,
            options: change == "options" ? [.firesOnRecordCreation] : [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        subscription.notificationInfo = CloudKitSchema.makeSubscription().notificationInfo
        return subscription
    }
    let subscription = CloudKitSchema.makeSubscription()
    if change == "zone" {
        subscription.zoneID = CKRecordZone.ID(zoneName: "other-zone")
        return subscription
    }
    if change == "notification" {
        subscription.notificationInfo = nil
        return subscription
    }
    let notification = subscription.notificationInfo!
    switch change {
    case "title": notification.title = "Other title"
    case "body": notification.alertBody = "Other body"
    case "sound": notification.soundName = "other"
    case "keys": notification.desiredKeys = [CloudKitSchema.occurredAtField]
    case "background": notification.shouldSendContentAvailable = true
    case "mutable": notification.shouldSendMutableContent = true
    case "badge": notification.shouldBadge = true
    case "category": notification.category = "other"
    case "collapse": notification.collapseIDKey = CloudKitSchema.occurredAtField
    case "alertLocalization": notification.alertLocalizationKey = "other"
    case "alertArgs": notification.alertLocalizationArgs = [CloudKitSchema.occurredAtField]
    case "titleLocalization": notification.titleLocalizationKey = "other"
    case "titleArgs": notification.titleLocalizationArgs = [CloudKitSchema.occurredAtField]
    case "subtitle": notification.subtitle = "Other subtitle"
    case "subtitleLocalization": notification.subtitleLocalizationKey = "other"
    case "subtitleArgs": notification.subtitleLocalizationArgs = [CloudKitSchema.occurredAtField]
    case "action": notification.alertActionLocalizationKey = "other"
    case "image": notification.alertLaunchImage = "other"
    default: preconditionFailure("Unknown fixture")
    }
    subscription.notificationInfo = notification
    return subscription
}
