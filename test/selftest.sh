#!/usr/bin/env bash
# dep-guard self-test: runs dep-guard.sh end to end in a throwaway git repo against the pinned rdv.
# Cases: RED (install hook on an unknown package → exit 1), GREEN (@rederive/* add → 0), YELLOW (plain
# unverified add → 0, surfaced), NO LOCKFILE (→ 0, notice). Network: the guard's best-effort npm/GitHub
# lookups; they degrade to "unknown" offline, which still yields the same verdicts here.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
RDV="${DEPGUARD_RDV:-npx --yes rederive@${DEPGUARD_RDV_VERSION:-0.5.3}}"
T="$(mktemp -d)"; cd "$T"; git init -q; git config user.email t@example.invalid; git config user.name t
echo '{"name":"x","version":"1.0.0"}' > package.json
echo '{"name":"x","version":"1.0.0","lockfileVersion":3,"requires":true,"packages":{"":{"name":"x","version":"1.0.0"}}}' > package-lock.json
git add -A; git commit -qm base; BASE="$(git rev-parse HEAD)"
FAILED=0
run() {   # $1 label  $2 expected exit
  DEPGUARD_RDV="$RDV" DEPGUARD_BASE_SHA="$BASE" DEPGUARD_CI=github GITHUB_WORKSPACE="$T" bash "$HERE/dep-guard.sh" > "$T/out.$1" 2>&1; rc=$?
  if [ "$rc" -eq "$2" ]; then echo "PASS  $1 (exit $rc): $(grep -m1 'dep-guard:' "$T/out.$1" | tail -c 80)"; else echo "FAIL  $1: exit $rc, expected $2"; cat "$T/out.$1"; FAILED=1; fi
}
lock() {   # $1 dep name  $2 version  $3 extra json for the package entry
  printf '{"name":"x","version":"1.0.0","lockfileVersion":3,"requires":true,"packages":{"":{"name":"x","version":"1.0.0","dependencies":{"%s":"%s"}},"node_modules/%s":{"version":"%s"%s}}}\n' "$1" "$2" "$1" "$2" "$3" > package-lock.json
}
lock zz-dep-guard-selftest-hook 1.0.0 ',"hasInstallScript":true';  run red 1
lock @rederive/colors 0.2.0 '';                                      run green 0
lock left-pad 1.3.0 '';                                              run yellow 0
rm package-lock.json;                                               run nolock 0
rm -rf "$T"
exit $FAILED
