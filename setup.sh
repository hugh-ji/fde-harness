#!/bin/sh
# Read this script before use. With no argument, install into the clone's parent.
# An explicit existing workspace path remains supported as the first argument.
# No overwrite, source deletion, git staging, commits, or network operations.
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
[ -w "$WS" ] || fail "Target is not writable: $WS"
command -v git >/dev/null 2>&1 || fail "Git is required to record the source commit."
SOURCE_ROOT=$(git -C "$KIT" rev-parse --show-toplevel) || fail "Use a Git clone of the harness."
[ "$SOURCE_ROOT" = "$KIT" ] || fail "The script must be at the harness checkout root."
[ -z "$(git -C "$KIT" status --porcelain --untracked-files=all)" ] || fail "Source checkout has changes. Use a reviewed, committed version."
SHA=$(git -C "$KIT" rev-parse --verify HEAD)

# Explicit allowlist: no glob copies of future files or arbitrary source data.
FILES='AGENTS.md
PROMPTS.md
templates/AGREEMENT.md
templates/PLAN.md
templates/DECISIONS.md
templates/HANDOFF.md
templates/SCREEN_CHECK.md
templates/CHECKLIST.md
.agents/skills/fde-interview/SKILL.md
.agents/skills/verify-before-done/SKILL.md
.agents/skills/handoff/SKILL.md'
DIRS='.agents
.agents/skills
.agents/skills/fde-interview
.agents/skills/verify-before-done
.agents/skills/handoff'

# All anticipated conflicts are checked before the first write.
for rel in $DIRS; do
    [ ! -L "$KIT/$rel" ] || fail "Source directory must not be a symbolic link: $rel"
    if [ -L "$WS/$rel" ] || { [ -e "$WS/$rel" ] && [ ! -d "$WS/$rel" ]; }; then
        fail "Destination directory conflict; nothing copied: $rel"
    fi
done
[ ! -L "$KIT/templates" ] || fail "Source templates directory must not be a symbolic link."
for src in $FILES; do
    [ -f "$KIT/$src" ] && [ ! -L "$KIT/$src" ] || fail "Missing or unsafe source file: $src"
    dst=${src#templates/}
    if [ -e "$WS/$dst" ] || [ -L "$WS/$dst" ]; then
        fail "Existing destination preserved; nothing copied: $dst. Keep official files and use the source as reference."
    fi
done
if [ -e "$WS/HARNESS_SOURCE.md" ] || [ -L "$WS/HARNESS_SOURCE.md" ]; then
    fail "Existing HARNESS_SOURCE.md preserved; nothing copied."
fi

for rel in $DIRS; do mkdir -p "$WS/$rel"; done
for src in $FILES; do cp "$KIT/$src" "$WS/${src#templates/}"; done
{
    printf '# Harness source\n\n'
    printf -- '- Repository: https://github.com/hugh-ji/fde-harness\n'
    printf -- '- Commit: %s\n' "$SHA"
    printf -- '- Installed at UTC: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf -- '- Purpose: general workflow and blank templates; not an official exam approval.\n'
    printf -- '- Source checkout retained. Existing files and Git index were not changed.\n'
    printf '\n## Imported paths\n\n'
    for src in $FILES; do printf -- '- `%s` -> `%s`\n' "$src" "${src#templates/}"; done
} > "$WS/HARNESS_SOURCE.md"
printf 'Installed reviewed harness %s into %s\n' "$SHA" "$WS"
printf 'Source preserved. No git init/add/commit was run. Review HARNESS_SOURCE.md and the applicable official rules.\n'
