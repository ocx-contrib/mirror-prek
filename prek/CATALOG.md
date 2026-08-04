---
title: prek
description: A fast Git hook manager written in Rust — a drop-in, dependency-free alternative to pre-commit
keywords: prek,pre-commit,git,git-hooks,hooks,lint,formatter,ci,rust,cli
---

# prek

[prek](https://github.com/j178/prek) manages Git hooks. It reads the same
`.pre-commit-config.yaml` that [pre-commit](https://pre-commit.com) does,
installs the same hook repositories, and runs the same hooks — but ships as a
single self-contained binary with no Python interpreter to bootstrap and no
virtualenv to keep alive.

That difference is the point. `prek install` writes the shim into
`.git/hooks/`; `prek run` executes the configured hooks against the files a
commit touches; `prek run --all-files` sweeps the whole tree. Hook environments
for Python, Node, Go, Rust and Ruby hooks are provisioned and cached by prek
itself, and `repo: local` hooks with `language: system` run directly with no
environment at all.

Beyond drop-in compatibility it adds a workspace model for monorepos (hooks
scoped per project, selected with `--directory` or by name), hook groups
(`--group`, `--skip`, `--require-group`), `--last-commit` and
`from_ref...to_ref` range selection, built-in reimplementations of the common
`pre-commit-hooks` checks, and `prek validate-config` / `validate-manifest` for
checking configuration without running anything.

## What's included

- **prek** — the hook manager. `prek install` installs the Git shims;
  `prek run [--all-files]` runs the configured hooks and exits non-zero if any
  hook fails; `prek list` prints the resolved `<project>:<hook-id>` set;
  `prek validate-config` checks a `.pre-commit-config.yaml` without executing
  it; `prek try-repo` runs hooks straight from a repository URL; `prek cache`
  manages the hook-environment store.

The release archive contains this single executable and nothing else.

## Install with ocx

```sh
ocx install ocx.sh/prek/prek
```

```sh
# or pin a specific version
ocx install ocx.sh/prek/prek:0.4.12
```

`prek` shells out to `git` — it is a Git hook manager — so a `git` executable
must be on `PATH` for `prek list`, `prek run` and `prek install`.

## Links

- [prek on GitHub](https://github.com/j178/prek)
- [Documentation site](https://prek.j178.dev/)
- [Compatibility with pre-commit](https://prek.j178.dev/compatibility/)
- [Configuration reference](https://prek.j178.dev/configuration/)
