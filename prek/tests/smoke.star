# prek/tests/smoke.star — stable across upstream prek releases.
#
# Asserts the contract (exit codes, version SHAPE, the COUNT of hooks prek
# resolved from a config it had to parse, the per-hook Passed/Failed verdicts
# it COMPUTED from real child-process exit codes, and the line:column a
# deliberately malformed config produces), never help/version prose.
#
# HERMETIC AND OFFLINE BY CONSTRUCTION. prek's headline feature is cloning hook
# repositories from GitHub and provisioning language runtimes for them — every
# one of those paths touches the network. The config below declares `repo:
# local` hooks with `language: system` only, which prek executes directly with
# no clone, no environment build and no download. `PREK_HOME` is pinned into
# the scratch sandbox so nothing is read from or written to a real user cache.
#
# WHY EVERY HOOK ENTRY IS `git`: prek is a git hook manager and already
# hard-requires git — `prek list` / `prek run` shell out to
# `git rev-parse --show-toplevel` as their first act and exit 2 without it. So
# using git as the hook command adds no dependency this package does not
# already have. The Linux container legs install it via `containers[].setup`
# (see ../../mirror-base.yml); every GitHub-hosted macOS and Windows runner
# ships it.

PREK = "prek.exe" if ocx.target_platform.os == ocx.os.Windows else "prek"

# Pin the tool's own home inside the sandbox. `type: path`-style state must not
# leak into a runner's real cache directory, and a read-only HOME would
# otherwise be a platform-specific failure mode rather than a contract check.
ENV = {"PREK_HOME": ocx.scratch_root + "/.prek-home"}

# ─── Tier 1 + 2: liveness on the composed PATH + version SHAPE ──────────────
#
# The digits are the contract; the banner text is not. `prek 0.4.12` today,
# some other product name after a rebrand — the regex survives that, an
# `expect.contains(…, "prek")` would not.
r_version = ocx.run(PREK, "--version", env = ENV)
expect.ok(r_version)
expect.matches(r_version.stdout, r"\d+\.\d+\.\d+")

# ─── Hermetic fixtures ──────────────────────────────────────────────────────
#
# Two `repo: local` / `language: system` hooks with deterministic, opposite
# outcomes in ANY git repository:
#
#   repo-root-known  `git rev-parse --git-dir`                        → exit 0
#   absent-ref       `git rev-parse --verify --quiet refs/heads/…`    → exit 1
#
# `pass_filenames: false` + `always_run: true` means neither depends on which
# files are staged, so the asserted verdicts come from the hook processes' own
# exit codes and from nothing else.
ocx.write_file(".pre-commit-config.yaml", """repos:
  - repo: local
    hooks:
      - id: repo-root-known
        name: repo-root-known
        language: system
        entry: git rev-parse --git-dir
        pass_filenames: false
        always_run: true
      - id: absent-ref
        name: absent-ref
        language: system
        entry: git rev-parse --verify --quiet refs/heads/ocx-smoke-absent
        pass_filenames: false
        always_run: true
""")

# The NEGATIVE CONTROL's fixture: a hook entry missing the REQUIRED `name`
# field. Structurally it is valid YAML — so this cannot pass on a YAML syntax
# error alone; only prek's own schema validation rejects it.
ocx.write_file("malformed.yaml", """repos:
  - repo: local
    hooks:
      - id: nameless
""")

# ─── Tier 3a: config validation, the positive case ──────────────────────────
#
# `validate-config` is the one prek verb that needs no git repository, so this
# half runs identically in a bare container and on a runner. prek writes its
# result to STDERR (stdout stays empty), which is itself part of the contract
# being asserted.
r_ok = ocx.run(PREK, "validate-config", ".pre-commit-config.yaml", env = ENV)
expect.ok(r_ok)
expect.eq(r_ok.stdout, "")
expect.contains(r_ok.stderr, "All configs are valid")

# ─── Tier 3b: THE NEGATIVE CONTROL ──────────────────────────────────────────
#
# A validator that rubber-stamped its input — or one whose schema layer never
# ran — would exit 0 here. Exit 1 alone is not the assertion: `4:9` is the
# line:column prek COMPUTED for the offending node, and "missing field `name`"
# names the field it worked out was absent. Neither string appears anywhere in
# this script's inputs, so emitting them is proof the schema engine walked the
# document rather than pattern-matching it.
r_bad = ocx.run(PREK, "validate-config", "malformed.yaml", env = ENV)
expect.eq(r_bad.exit_code, 1)
expect.contains(r_bad.stderr, "missing field `name`")
expect.matches(r_bad.stderr, r"<input>:4:9")

# ─── A throwaway git repository, created in scratch ─────────────────────────
#
# `cwd` defaults to the scratch root, so the repo, the config and the tracked
# file are all siblings and every path below stays relative — correct on
# Windows too, with no separator juggling. `-b main` avoids git's default-branch
# advice on stderr. No commit is needed: `--all-files` enumerates TRACKED files,
# and `git add` puts the file in the index, which is what makes it tracked.
expect.ok(ocx.run("git", "init", "-q", "-b", "main", ".", env = ENV))
ocx.write_file("tracked.txt", "hello\n")
expect.ok(ocx.run("git", "add", "tracked.txt", env = ENV))

# ─── Tier 3c: hook DISCOVERY — an asserted COUNT, not an exit code ──────────
#
# `prek list` emits one `<project>:<hook-id>` line per configured hook. Two
# hooks in, two lines out, in declaration order — a count prek had to derive by
# parsing the config, and a listing that silently found zero hooks would still
# exit 0.
r_list = ocx.run(PREK, "list", env = ENV)
expect.ok(r_list)
expect.eq(len(r_list.stdout.strip().split("\n")), 2)
expect.contains(r_list.stdout, ".:repo-root-known")
expect.contains(r_list.stdout, ".:absent-ref")

# ─── Tier 3d: hook EXECUTION — the actual product ───────────────────────────
#
# `--color never` keeps SGR escapes out of stdout so plain assertions are safe;
# `--no-progress` removes the spinner. The dot-fill between a hook's name and
# its verdict is terminal-width dependent, hence `\.+` rather than a literal.
#
# The overall exit code is 1 because exactly one hook failed — that is prek
# aggregating child exit codes, and it is the assertion that distinguishes
# "ran the hooks" from "printed a plan". Asserting only the Passed line would
# green a build that never executed anything.
r_run = ocx.run(PREK, "run", "--all-files", "--no-progress", "--color", "never", env = ENV)
expect.eq(r_run.exit_code, 1)
expect.matches(r_run.stdout, r"repo-root-known\.+Passed")
expect.matches(r_run.stdout, r"absent-ref\.+Failed")
# prek echoes the failing hook's own exit status; 1 is `git rev-parse
# --verify`'s answer for a ref that does not exist.
expect.contains(r_run.stdout, "- exit code: 1")

# No Tier 4: metadata.json declares PATH only (proven by Tier 1 liveness).
