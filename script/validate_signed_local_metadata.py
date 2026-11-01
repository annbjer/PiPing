"""Pure signed-local metadata checks; no Keychain, signing or network access."""

import datetime
import plistlib
import sys


def expected_app_entitlements(team, bundle, container):
    return {
        "com.apple.developer.icloud-container-identifiers": [container],
        "com.apple.developer.icloud-services": ["CloudKit"],
        "com.apple.developer.team-identifier": team,
        "com.apple.application-identifier": f"{team}.{bundle}",
    }


def prepare_release_entitlements(generated, team, bundle, container):
    # Xcode may inject debugger attachment even for Apple Development Release
    # signing. Remove ONLY this known boolean permission before final signing;
    # never silently drop an unknown capability or accept a mismatched identity.
    if not isinstance(generated, dict):
        raise ValueError("Generated signed entitlements are malformed.")
    result = generated.copy()
    debug_key = "com.apple.security.get-task-allow"
    if debug_key in result:
        if type(result[debug_key]) is not bool:
            raise ValueError("Generated debugger entitlement is malformed.")
        del result[debug_key]
    if result != expected_app_entitlements(team, bundle, container):
        raise ValueError("Generated app has unexpected entitlements or identity.")
    return result


def validate_metadata(app_entitlements, helper_entitlements, profile,
                      app_certificate, helper_certificate, team, bundle, container):
    application_identifier = f"{team}.{bundle}"
    if app_entitlements != expected_app_entitlements(team, bundle, container):
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
    # Apple Mac profiles may encode a scalar wildcard ceiling. It authorizes
    # the requested service, not additional actual app/helper entitlements.
    authorized = profile_services == "*" or (
        isinstance(profile_services, list)
        and all(isinstance(service, str) for service in profile_services)
        and any(service in profile_services for service in ("CloudKit", "*")))
    if not authorized:
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
    if arguments and arguments[0] == "--prepare-release-entitlements":
        _, generated_path, output_path, team, bundle, container = arguments
        with open(generated_path, "rb") as handle:
            generated = plistlib.load(handle)
        prepared = prepare_release_entitlements(generated, team, bundle, container)
        with open(output_path, "xb") as handle:
            plistlib.dump(prepared, handle)
        return
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
