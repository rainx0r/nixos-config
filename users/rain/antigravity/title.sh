#!/usr/bin/env bash
set -euo pipefail

jq -r '.conversation_title // empty' 2>/dev/null || true
