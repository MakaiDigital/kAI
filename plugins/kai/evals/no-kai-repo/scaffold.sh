#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/../_fixture/make_repo.sh"
make_repo plain
