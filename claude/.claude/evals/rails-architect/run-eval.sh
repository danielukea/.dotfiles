#!/bin/bash
# Run rails-architect eval cases and save outputs for scoring
#
# Usage:
#   ./run-eval.sh                    # Run all cases, save to output/current/
#   ./run-eval.sh --label modified   # Run all cases, save to output/modified/
#   ./run-eval.sh --case 01          # Run only case 01
#   ./run-eval.sh --dry-run          # Show prompts without running

set -euo pipefail

EVAL_DIR="$(cd "$(dirname "$0")" && pwd)"
CASES_DIR="$EVAL_DIR/cases"
LABEL="current"
SINGLE_CASE=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --label) LABEL="$2"; shift 2 ;;
    --case) SINGLE_CASE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

OUTPUT_DIR="$EVAL_DIR/output/$LABEL"
mkdir -p "$OUTPUT_DIR"

echo "=== rails-architect eval ==="
echo "Label: $LABEL"
echo "Output: $OUTPUT_DIR"
echo ""

for f in "$CASES_DIR"/*.md; do
  case_name=$(basename "$f" .md)

  if [[ -n "$SINGLE_CASE" && "$case_name" != *"$SINGLE_CASE"* ]]; then
    continue
  fi

  echo "--- $case_name ---"

  if $DRY_RUN; then
    echo "PROMPT:"
    cat "$f"
    echo ""
    continue
  fi

  echo "Running... (this may take a few minutes)"
  # Run with rails-architect agent, capture output
  claude -p "$(cat "$f")" --agent rails-architect > "$OUTPUT_DIR/$case_name.out.md" 2>&1 || true

  echo "Saved to $OUTPUT_DIR/$case_name.out.md"
  echo ""
done

if ! $DRY_RUN; then
  echo "=== Done ==="
  echo "Outputs in: $OUTPUT_DIR"
  echo ""
  echo "Next: score each output using rubric.md"
  echo "  Compare: diff output/current/ output/modified/"
fi
