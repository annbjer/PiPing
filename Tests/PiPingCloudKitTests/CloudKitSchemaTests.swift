@preconcurrency import CloudKit
import Foundation
import PiPingCore
import Testing
@testable import PiPingCloudKit

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
    }
}
