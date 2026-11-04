# rederive dep-guard — a PR gate on risky dependency adds

Gate a pull request on the dependencies it **adds** or bumps, on your own infra, with no data egress beyond the guard's
own best-effort metadata lookups. The "a junior slipped `left-pad` or a hook-bearing worm into a PR" case. One script
drives both GitHub Actions and Azure DevOps and emits each CI's native annotations and summary.

- **RED** (blocks): an install hook (`preinstall` / `install` / `postinstall`) on a *non-established* package — not on
  the allowlist of known native build-step packages, and fewer than 5 GitHub contributors. The worm / typosquat vector.
- **YELLOW** (surfaces): a new direct dependency with no rederive contract; a package less than 30 days old.
- **GREEN**: a `@rederive/*` package, or a clean add. Established native binaries (esbuild, fsevents, sharp, …) are
  build steps, not worms.

The hard signals need no network: install hooks come from the lockfile's own flags (`hasInstallScript` for npm,
`onlyBuiltDependencies` for pnpm), so the gate works behind a private registry. GitHub and npm metadata are garnish —
they degrade to "unknown" and never block when unavailable. Direct dependencies are nagged individually; transitives
roll up into one count, except a transitive that trips a hard signal, which is escalated on its own.

**Only the root lockfile is read** (`pnpm-lock.yaml`, else `package-lock.json`). Lockfiles in subdirectories are not
gated. A repo with no root lockfile gets a notice ("nothing to gate") and passes.

The verdict itself is [`rdv guard`](https://github.com/rederive/rederive#the-commands) from the `rederive` npm package,
run at an **exact, pinned version** (`npx --yes rederive@<rederive-version>`), so the verifier cannot move under you.

## GitHub Actions

Copy [`example-workflow.yml`](example-workflow.yml) to `.github/workflows/dep-guard.yml`:

```yaml
- uses: actions/checkout@v4
  with: { fetch-depth: 0 }          # the base ref must be present to diff the lockfile
- uses: rederive/dep-guard@v1       # or an exact release: rederive/dep-guard@v1.0.0
  with:
    rederive-version: '0.5.3'       # the exact rdv the guard runs
    fail-closed: 'true'
```

Needs `permissions: contents: read` and nothing more. Pin `@v1` (moves with compatible releases) or an exact
`@v1.x.y`; never `@main`.

## Azure DevOps

Copy `dep-guard.sh` from a tagged release into your repo (e.g. `tools/dep-guard.sh`) and use
[`azure-pipelines-dep-guard.yml`](azure-pipelines-dep-guard.yml) as a pipeline (or fold its steps into one), added as a
**build-validation branch policy** so it runs on PRs. Needs `fetchDepth: 0`. Emits `##vso[task.logissue]` annotations and
a build summary; a RED fails the task and blocks the PR.

The script auto-detects the CI (`GITHUB_ACTIONS` / `TF_BUILD`).

## Inputs (GitHub) / environment (ADO)

| input | env | default | |
|---|---|---|---|
| `rederive-version` | `DEPGUARD_RDV_VERSION` | `0.5.3` | the exact verifier version: runs `npx --yes rederive@<version>` |
| `fail-closed` | `DEPGUARD_FAIL_CLOSED` | `true` | see below |
| `rdv` | `DEPGUARD_RDV` | (empty) | advanced: replace the whole invocation, e.g. `node ./dist/cli.cjs` for a local build |

The guard always runs with `--reporter json`; the script renders each CI's native annotations from that JSON.

## Exit codes and failure mode

| exit | meaning |
|---|---|
| 0 | green / yellow, or no root lockfile (notice) |
| 1 | RED — blocks the PR |
| 2 | the guard itself failed: `npx`/`rdv` crashed, or printed empty or invalid JSON |

The guard **fails closed** by default: a crash is exit 2 and fails the check, because a gate that silently passes when
it cannot run is not a gate. Set `fail-closed: 'false'` (GitHub) or `DEPGUARD_FAIL_CLOSED: 'false'` (ADO) to turn a
guard failure into a warning and a pass.

## Allowlisting your own hook-bearing packages

Teams with private native packages that legitimately run an install step extend the allowlist with a `.dep-guard.json`
at the repo root; see the `rdv guard` documentation in the rederive repo.

## Self-test

```
bash test/selftest.sh      # RED, GREEN, YELLOW and no-lockfile cases, end to end against the pinned rdv
```

## Versioning

This action has its own semver (`v1.x.y`, with `v1` moving to the latest compatible release). The `rederive-version`
default is the rdv the release was tested with; bump it explicitly when you want a newer verifier.

## Provenance and license

Split out of the rederive monorepo ([`rederive/rederive`](https://github.com/rederive/rederive), `dep-guard-action/` as
of 5e7f29c; tags `v0.5.0`–`v0.5.3` there still carry the in-tree copy). Apache-2.0, © 2026 Apilify Inc. Part of
[rederive](https://rederive.ai): `rdv audit` reports a project's real dependency surface, this gate guards the change
in a PR, and [sir-review](https://github.com/rederive/sir-review) guards changes to SIR contracts.
