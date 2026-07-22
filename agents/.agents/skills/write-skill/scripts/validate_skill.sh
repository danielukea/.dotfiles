#!/usr/bin/env bash
# validate_skill.sh — portable sanity checks for a SKILL.md.
#
# Usage: validate_skill.sh <path-to-SKILL.md | path-to-skill-dir>
#
# Checks (craft only — nothing about how the skill is installed/linked):
#   - frontmatter present, with a non-empty `name:` and `description:`
#   - `name:` matches the skill's folder name
#   - description length: warn above ~60 tokens, FAIL above the 120-token ceiling
#   - a `## Gotchas` section exists
#   - any references/ | templates/ | scripts/ path named in SKILL.md exists on disk (warn)
#
# Token count is an estimate (~4 chars/token). Exit 0 on pass (warnings allowed),
# 1 on failure or bad input.

set -euo pipefail

WARN_TOKENS=60
MAX_TOKENS=120

target="${1:-}"
if [ -z "$target" ]; then
  echo "usage: validate_skill.sh <path-to-SKILL.md | skill-dir>" >&2
  exit 1
fi
[ -d "$target" ] && target="$target/SKILL.md"
if [ ! -f "$target" ]; then
  echo "FAIL: no SKILL.md at $target" >&2
  exit 1
fi

skill_dir="$(cd "$(dirname "$target")" && pwd)"
folder="$(basename "$skill_dir")"

fail=0
warn=0

# Extract the YAML frontmatter block (between the first two `---` lines).
frontmatter="$(awk 'NR==1 && $0!="---"{exit} /^---[[:space:]]*$/{c++; next} c==1{print} c>=2{exit}' "$target")"
if [ -z "$frontmatter" ]; then
  echo "FAIL: no YAML frontmatter (--- ... ---) at top of $target" >&2
  exit 1
fi

grep -qE '^name:[[:space:]]*[^[:space:]]' <<<"$frontmatter" \
  || { echo "FAIL: frontmatter missing a non-empty 'name:'" >&2; fail=1; }
grep -qE '^description:' <<<"$frontmatter" \
  || { echo "FAIL: frontmatter missing 'description:'" >&2; fail=1; }

# name: must match the skill's folder name (the folder drives discovery).
name_val="$(sed -n 's/^name:[[:space:]]*//p' <<<"$frontmatter" | head -1 \
  | sed 's/[[:space:]]*$//; s/^["'\'']//; s/["'\'']$//')"
if [ -n "$name_val" ] && [ "$name_val" != "$folder" ]; then
  echo "FAIL: name '$name_val' != folder '$folder' — they must match" >&2
  fail=1
elif [ -n "$name_val" ]; then
  echo "ok: name matches folder ($folder)"
fi

# Pull the description value, including YAML block-scalar (`>` / `|`) continuation lines.
description="$(awk '
  /^description:/ {
    sub(/^description:[[:space:]]*/, "")
    gsub(/^[>|][+-]?[[:space:]]*/, "")   # strip a block-scalar indicator
    print
    indesc=1
    next
  }
  indesc==1 {
    if ($0 ~ /^[A-Za-z0-9_-]+:/) { exit }   # next frontmatter key ends the value
    sub(/^[[:space:]]+/, "")
    print
  }
' <<<"$frontmatter" | tr '\n' ' ' | sed 's/[[:space:]]\{1,\}/ /g; s/^ //; s/ $//')"

if grep -qE '^description:' <<<"$frontmatter" && [ -z "$description" ]; then
  echo "FAIL: 'description:' present but has no value" >&2
  fail=1
fi

if [ -n "$description" ]; then
  chars=${#description}
  tokens=$(( (chars + 3) / 4 ))
  if [ "$tokens" -gt "$MAX_TOKENS" ]; then
    echo "FAIL: description ~${tokens} tokens (>${MAX_TOKENS} ceiling) — trim it" >&2
    fail=1
  elif [ "$tokens" -gt "$WARN_TOKENS" ]; then
    echo "WARN: description ~${tokens} tokens (>${WARN_TOKENS}) — start leaner, grow only if it under-triggers" >&2
    warn=1
  else
    echo "ok: description ~${tokens} tokens"
  fi
fi

# A `## Gotchas` section (any case) should exist so there's a place to grow.
if grep -qiE '^##[[:space:]]+gotchas' "$target"; then
  echo "ok: '## Gotchas' section present"
else
  echo "FAIL: no '## Gotchas' section — every skill should carry one to append to" >&2
  fail=1
fi

# Any references/ | templates/ | scripts/ path named in SKILL.md should exist on disk.
missing=""
while IFS= read -r p; do
  [ -z "$p" ] && continue
  [ -e "$skill_dir/$p" ] || missing="$missing $p"
done < <(grep -oE '(references|templates|scripts)/[A-Za-z0-9._/-]+' "$target" \
  | sed 's/[).,;:]*$//' | sort -u)
if [ -n "$missing" ]; then
  echo "WARN: SKILL.md names path(s) not found on disk:$missing" >&2
  warn=1
else
  echo "ok: referenced paths exist"
fi

if [ "$fail" -ne 0 ]; then
  echo "validate_skill.sh: FAILED" >&2
  exit 1
fi
[ "$warn" -ne 0 ] && echo "validate_skill.sh: passed with warnings"
[ "$warn" -eq 0 ] && echo "validate_skill.sh: passed"
exit 0
