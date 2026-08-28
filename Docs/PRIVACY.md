# Privacy

PiPing is content-free by design.

## Allowed data

The local lifecycle protocol contains exactly one of two strings: `start` or
`settled`. CloudKit overwrites one fixed rolling record whose only
application-defined field is the `occurredAt` timestamp. Notification title and
body are compile-time constants.

## Prohibited data

The app, helper, hook, tests, fixtures, and documentation must not collect,
store, log, or transmit:

- prompts, system prompts, model responses, or tool results;
- code, files, logs, paths, project names, or session identifiers;
- terminal output, commands, approvals, credentials, or model/provider names;
- personal names, email addresses, device identifiers, or account identifiers.

## Repository invariant

Source must be public-safe from its first commit. User-specific settings belong
in Keychain, Xcode user data, ignored local files, or locations outside the
checkout. Tests use synthetic fixtures. Sanitizing a repository only before
publication is not an acceptable workflow.
