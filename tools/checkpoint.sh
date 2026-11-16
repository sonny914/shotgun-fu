#!/usr/bin/env bash
# Tag a known-good state: clean tree + full validation green -> annotated tag checkpoint/<date>-<name>.
# Does NOT push. Push tags explicitly: git push origin <tag>
set -euo pipefail
cd "$(dirname "$0")/.."
NAME="${1:?usage: tools/checkpoint.sh <name> [message]}"
MSG="${2:-Checkpoint $NAME}"
[[ "$NAME" =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "name must be kebab-case" >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "working tree not clean — commit first" >&2; exit 1; }
tools/validate.sh --full
TAG="checkpoint/$(date +%Y%m%d)-$NAME"
git tag -a "$TAG" -m "$MSG"
echo "Tagged $TAG at $(git rev-parse --short HEAD). Push with: git push origin $TAG"
