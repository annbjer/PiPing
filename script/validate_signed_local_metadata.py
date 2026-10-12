"""Pure signed-local metadata checks; no Keychain, signing or network access."""

import datetime
import plistlib
import sys


def validate_metadata(app_entitlements, helper_entitlements, profile,
                      app_certificate, helper_certificate, team, bundle, container):
    application_identifier = f"{team}.{bundle}"
    expected_entitlements = {
        "com.apple.developer.icloud-container-identifiers": [container],
        "com.apple.developer.icloud-services": ["CloudKit"],
        "com.apple.developer.team-identifier": team,
        "com.apple.application-identifier": application_identifier,
    }
    if app_entitlements != expected_entitlements:
        raise ValueError("Signed local app must have only the exact approved CloudKit and identity entitlements.")
    if helper_entitlements != {}:
        raise ValueError("Signed local helper must not contain any entitlements.")
    if not isinstance(profile, dict):
        raise ValueError("Provisioning profile is malformed.")
    if profile.get("TeamIdentifier") != [team]:
        raise ValueError("Provisioning profile has an unexpected team.")
    if profile.get("ApplicationIdentifierPrefix") != [team]:
        raise ValueError("Provisioning profile has an unexpected application prefix.")
    profile_entitlements = profile.get("Entitlements", {})
    if not isinstance(profile_entitlements, dict):
        raise ValueError("Provisioning profile entitlements are malformed.")
    if profile_entitlements.get("com.apple.application-identifier") != application_identifier:
        raise ValueError("Provisioning profile has an unexpected application identifier.")
    if profile_entitlements.get("com.apple.developer.icloud-container-identifiers") != [container]:
        raise ValueError("Provisioning profile has an unexpected iCloud container.")
    profile_services = profile_entitlements.get("com.apple.developer.icloud-services")
    if (not isinstance(profile_services, list)
            or not all(isinstance(service, str) for service in profile_services)
            or "CloudKit" not in profile_services):
        raise ValueError("Provisioning profile does not authorize the requested CloudKit service.")
    # A profile authorizes a capability ceiling, not the actual app/helper
    # entitlement set. Profile UUID/hash/capability-set pinning is not claimed.
    developer_certificates = profile.get("DeveloperCertificates", [])
    if not app_certificate or app_certificate != helper_certificate:
        raise ValueError("Signed local app and helper use missing or different leaf certificates.")
    if app_certificate not in developer_certificates:
        raise ValueError("Signed local app/helper certificate is not authorized by the profile.")
    expiration = profile.get("ExpirationDate")
    if not isinstance(expiration, datetime.datetime):
        raise ValueError("Provisioning profile has no valid expiration date.")
    if expiration.tzinfo is None:
        expiration = expiration.replace(tzinfo=datetime.timezone.utc)
    if expiration <= datetime.datetime.now(datetime.timezone.utc):
        raise ValueError("Provisioning profile has expired.")


def main(arguments):
    (app_path, helper_path, profile_path, app_certificate_path,
     helper_certificate_path, team, bundle, container) = arguments
    with open(app_path, "rb") as handle:
        app_entitlements = plistlib.load(handle)
    with open(helper_path, "rb") as handle:
        helper_data = handle.read()
        # codesign emits no plist for a binary with no entitlement blob. A
        # command failure is rejected by the calling shell, not treated as empty.
        helper_entitlements = plistlib.loads(helper_data) if helper_data else {}
    with open(profile_path, "rb") as handle:
        profile = plistlib.load(handle)
    with open(app_certificate_path, "rb") as handle:
        app_certificate = handle.read()
    with open(helper_certificate_path, "rb") as handle:
        helper_certificate = handle.read()
    validate_metadata(app_entitlements, helper_entitlements, profile,
                      app_certificate, helper_certificate, team, bundle, container)


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except Exception:
        # Do not echo private entitlement/profile contents or paths on failure.
        raise SystemExit("Signed local app/helper entitlements or provisioning metadata are not approved.")
