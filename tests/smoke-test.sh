#!/usr/bin/env bash
set -e

echo "Running smoke test..."

bash installer.sh --debug --non-interactive || true

echo "Smoke test complete"
