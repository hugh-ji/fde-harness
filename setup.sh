#!/bin/sh
# Read this script before use. With no argument, install into the clone's parent.
# An explicit existing workspace path remains supported as the first argument.
# No overwrite, git staging, commits, or network operations.
# PROFILE selects an environment policy appended to the installed AGENTS.md
# (default: cofa; PROFILE=none installs the generic kit only).
# After a successful install the clone itself is removed (set KEEP_SOURCE=1 to keep it);
# the source URL and commit stay recorded in HARNESS_SOURCE.md.
main() {
    set -eu
    fail() { printf '%s\n' "$*" >&2; exit 1; }
    KIT=$(CDPATH= cd -P -- "$(dirname -- "$0")" && pwd)
    case "$#" in
        0) TARGET=$(dirname -- "$KIT") ;;
        1) TARGET=$1 ;;
        *) fail "Usage: sh setup.sh [existing-workspace]" ;;
    esac
    [ -d "$TARGET" ] || fail "Target must be an existing directory: $TARGET"
    [ ! -L "$TARGET" ] || fail "Target must not be a symbolic link."
    WS=$(CDPATH= cd -P -- "$TARGET" && pwd)
    case "$WS/" in "$KIT/"*) fail "Target must be outside the source checkout." ;; esac
    [ -w "$WS" ] || fail "Target is not writable: $WS. Do NOT change permissions. Clone again inside the writable submission folder (for example its users/ subfolder) and run setup.sh from there."
    command -v git >/dev/null 2>&1 || fail "Git is required to record the source commit."
    git -C "$KIT" rev-parse --show-toplevel >/dev/null 2>&1 || fail "Use a Git clone of the harness."
    # --show-prefix is empty only at the checkout root; avoids path-string comparison (Unicode normalization on macOS).
    [ -z "$(git -C "$KIT" rev-parse --show-prefix)" ] || fail "The script must be at the harness checkout root."
    [ -z "$(git -C "$KIT" status --porcelain --untracked-files=all)" ] || fail "Source checkout has changes. Use a reviewed, committed version."
    SHA=$(git -C "$KIT" rev-parse --verify HEAD)

    # Explicit allowlist: no glob copies of future files or arbitrary source data.
    PROFILE=${PROFILE:-cofa}
    case "$PROFILE" in
        none) PROFILE_POLICY=''; PROFILE_FILES='templates/COLLABORATION.md' ;;
        */*|.*|'') fail "Invalid PROFILE: $PROFILE" ;;
        *) PROFILE_POLICY="profiles/$PROFILE.md"
           [ -f "$KIT/$PROFILE_POLICY" ] && [ ! -L "$KIT/$PROFILE_POLICY" ] || fail "Unknown PROFILE: $PROFILE (missing $PROFILE_POLICY)"
           PROFILE_FILES=$( [ -d "$KIT/profiles/$PROFILE" ] && cd "$KIT" && find "profiles/$PROFILE" -maxdepth 1 -type f -name '*.md' | LC_ALL=C sort || true ) ;;
    esac
    FILES="AGENTS.md
    PROMPTS.md
    templates/PLAN.md
    templates/DECISIONS.md
    templates/HANDOFF.md
    $PROFILE_FILES"
    DIRS=''
    dst_of() { case "$1" in templates/*) printf '%s' "${1#templates/}" ;; profiles/*/*) printf '%s' "${1#profiles/*/}" ;; *) printf '%s' "$1" ;; esac; }

    # All anticipated conflicts are checked before the first write.
    for rel in $DIRS; do
        [ -n "$rel" ] || continue
        [ ! -L "$KIT/$rel" ] || fail "Source directory must not be a symbolic link: $rel"
        if [ -L "$WS/$rel" ] || { [ -e "$WS/$rel" ] && [ ! -d "$WS/$rel" ]; }; then
            fail "Destination directory conflict; nothing copied: $rel"
        fi
    done
    [ ! -L "$KIT/templates" ] || fail "Source templates directory must not be a symbolic link."
    for src in $FILES; do
        [ -f "$KIT/$src" ] && [ ! -L "$KIT/$src" ] || fail "Missing or unsafe source file: $src"
        dst=$(dst_of "$src")
        if [ -e "$WS/$dst" ] || [ -L "$WS/$dst" ]; then
            fail "Existing destination preserved; nothing copied: $dst. Keep official files and use the source as reference."
        fi
    done
    if [ -e "$WS/HARNESS_SOURCE.md" ] || [ -L "$WS/HARNESS_SOURCE.md" ]; then
        fail "Existing HARNESS_SOURCE.md preserved; nothing copied."
    fi

    for rel in $DIRS; do [ -n "$rel" ] && mkdir -p "$WS/$rel"; done
    for src in $FILES; do cp "$KIT/$src" "$WS/$(dst_of "$src")"; done
    if [ -n "$PROFILE_POLICY" ]; then printf '\n' >> "$WS/AGENTS.md"; cat "$KIT/$PROFILE_POLICY" >> "$WS/AGENTS.md"; fi
    {
        printf '# Harness source\n\n'
        printf -- '- Repository: https://github.com/hugh-ji/fde-harness\n'
        printf -- '- Commit: %s\n' "$SHA"
        printf -- '- Installed at UTC: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        printf -- '- Purpose: general workflow and blank templates; not an official exam approval.\n'
        if [ "${KEEP_SOURCE:-0}" = 1 ]; then
            printf -- '- Source checkout retained (KEEP_SOURCE=1). Existing files and Git index were not changed.\n'
        else
            printf -- '- Source clone removed after install. Existing files and Git index were not changed.\n'
        fi
        printf '\n## Imported paths\n\n'
        printf -- '- Profile: %s\n' "$PROFILE"
        for src in $FILES; do printf -- '- `%s` -> `%s`\n' "$src" "$(dst_of "$src")"; done
        [ -z "$PROFILE_POLICY" ] || printf -- '- `%s` appended to `AGENTS.md`\n' "$PROFILE_POLICY"
    } > "$WS/HARNESS_SOURCE.md"
    printf 'Installed reviewed harness %s into %s\n' "$SHA" "$WS"
    if [ "${KEEP_SOURCE:-0}" = 1 ]; then
        printf 'Source clone kept (KEEP_SOURCE=1). No git init/add/commit was run. Review HARNESS_SOURCE.md and the applicable official rules.\n'
    else
        rm -rf -- "$KIT"
        printf 'Source clone removed: %s. No git init/add/commit was run. Review HARNESS_SOURCE.md and the applicable official rules.\n' "$KIT"
    fi
}
main "$@"
