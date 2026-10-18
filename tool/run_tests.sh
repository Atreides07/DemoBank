#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
task_flutter="${FLUTTER_BIN:-flutter}"
for task_dir in packages/bank_core packages/ledger_data packages/payment_domain packages/network_client packages/network_simulation services/demo_api; do
  if [[ -d "$task_dir/test" ]]; then
    (cd "$task_dir" && "$task_flutter" pub run test --reporter expanded)
  fi
done
for task_dir in packages/app_localizations packages/design_system packages/local_storage packages/checkout packages/features/* packages/app_foundation packages/bank_experience apps/*; do
  if [[ -d "$task_dir/test" ]] && [[ -n "$(find "$task_dir/test" -name '*_test.dart' -print -quit)" ]]; then
    (cd "$task_dir" && "$task_flutter" test --no-pub --reporter expanded)
  fi
done
"$task_flutter" test --no-pub test
