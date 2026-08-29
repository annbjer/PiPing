# Pre-publication release-surface audit

A candidate push, visibility change, tag, release-asset upload, GitHub release,
public announcement/publication, or gallery listing is prohibited until this
checklist is complete for the exact candidate revision and the owner separately
approves that specific action.

## Required surfaces

- tracked files and submodules;
- untracked and ignored files;
- hidden tooling metadata;
- every reachable object in full Git history;
- generated archives and release bundles; and
- the exact extracted `git archive` payload.

## Required searches

Search for personal names, email addresses, absolute home paths, device IDs and
UDIDs, unnecessary Apple Team IDs, private CloudKit identifiers, tokens,
credentials, `.p8`, provisioning profiles, local xcconfig files, `.env*`,
`.xcuserdata`, DerivedData, result bundles, logs, and editor/agent metadata.

Inspect at minimum:

```bash
git status --short --ignored
git ls-files
git ls-files --others --exclude-standard
git log --all --stat --oneline
git rev-list --objects --all
```

Create the candidate archive in a temporary directory, list it, extract it, and
scan the extracted bytes—not merely the working tree.

If a credential ever entered history, rotate it first and then clean or restart
history. Deleting the current file or adding it to `.gitignore` is insufficient.

Treat `dist/source-local/`, source-install rollback archives, and uninstall
recovery archives as generated local artifacts; validate them for local testing
but never include them in a source-only release attachment allowlist.

Publication additionally requires a clean Daybreak scan, an approved
open-source license, and independent explicit approval for candidate push,
public visibility, tag, release assets, GitHub release, public announcement or
publication, and gallery listing as separate gates. Because GitHub
private vulnerability reporting becomes available only after public visibility,
enable and exercise it immediately after the separately approved visibility
change and before any tag, release, public announcement, or gallery listing.
