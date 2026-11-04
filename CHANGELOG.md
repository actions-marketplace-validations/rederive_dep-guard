# Changelog

## 1.0.0
- Split out of the rederive monorepo (`rederive/rederive`, `dep-guard-action/` as of 5e7f29c) into its own repo so it
  can be listed on the GitHub Marketplace and pinned as `rederive/dep-guard@v1`. Same script, same inputs. Verifier
  pinned to rederive 0.5.3. Adds a self-test (`test/selftest.sh`) that runs the gate end to end against the pinned rdv.
