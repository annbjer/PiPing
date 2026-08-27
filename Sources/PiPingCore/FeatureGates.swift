import Foundation

public enum FeatureGates {
    public static let cloudKitInfoKey = "PiPingCloudKitActivationEnabled"

    /// Defaults to false and can only be enabled by the signed app's generated
    /// Info.plist after the entitlements and account-specific setup are approved.
    public static var cloudKitActivationEnabled: Bool {
        cloudKitActivationEnabled(value: Bundle.main.object(forInfoDictionaryKey: cloudKitInfoKey))
    }

    static func cloudKitActivationEnabled(value: Any?) -> Bool {
        if let value = value as? Bool {
            return value
        }
        if let value = value as? NSNumber {
            return value.boolValue
        }
        if let value = value as? String {
            return ["1", "true", "yes"].contains(value.lowercased())
        }
        return false
    }

    /// Phase 1 must not expose any control or reply surface.
    public static let phaseTwoControlsEnabled = false
}
