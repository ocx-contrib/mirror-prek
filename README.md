# mirror-prek

OCX mirror for [prek](https://github.com/j178/prek), a fast Git hook manager
written in Rust and a drop-in alternative to pre-commit. One repository, one
spec directory per package.

| Package | Spec | Publishes to | Announced as | Upstream SPDX |
|---|---|---|---|---|
| [prek](https://github.com/j178/prek) | [`prek/mirror.yml`](prek/mirror.yml) | `ghcr.io/ocx-contrib/prek/prek` | [`ocx.sh/prek/prek`](https://index.ocx.sh/prek/prek) | `MIT` |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

`j178` is a personal handle rather than a vendor, so the tool names itself: the
namespace is `prek`, not the maintainer.

## Layout

```
mirror-base.yml         repo-wide policy the spec inherits via `extends:`
prek/
├── mirror.yml          the spec — never at the repo root
├── metadata.json       bundle interface
├── CATALOG.md          → ocx package describe
├── logo.svg / logo.png describe assets, 512px PNG
└── tests/smoke.star    Starlark smoke test
```

`LICENSE` and `NOTICE.md` are shared at the root. The logo is **not** — it sits
beside the spec, because a repo-root `logo.*` sits in no workflow's `paths:`
filter, so replacing it would publish nothing until some unrelated edit
happened to fire.

⚠️ `extends:` is a **shallow** merge of top-level keys. A spec that restates
`platforms:` to change one runner drops every `containers:` entry with it, and
nothing reds — the legs simply stop existing, and every `os.features` claim
goes back to being asserted rather than verified. `prek/mirror.yml` does not
restate `platforms:` at all; the measured matrix lives in `mirror-base.yml`.

## Platforms

Six platform entries: both Linux arches, both macOS arches, both Windows
arches. Every in-range release (v0.4.10, v0.4.11, v0.4.12) carries an
**identical 39-asset set**, re-listed per tag, and each of the six anchored
patterns matches exactly one asset on every one of them — a pattern matching
zero is *silently skipped* by the pipeline, not an error, and would ship a
missing platform under a green run.

**Both Linux keys are bare, because the artifacts this mirror carries are
static.** `os.features` states what an artifact requires *of the host*, never
how it was built:

| Key | Asset | Measured (v0.4.10 and v0.4.12) |
|---|---|---|
| `linux/amd64` | `prek-x86_64-unknown-linux-musl.tar.gz` | `static-pie linked`, `INTERP` **0**, `DT_NEEDED` **0**, no `GLIBC_*` symbol versions → **bare** |
| `linux/arm64` | `prek-aarch64-unknown-linux-musl.tar.gz` | `statically linked`, identical on all three counts → **bare** |

Upstream *also* ships `-gnu` builds for both arches, and those are genuinely
dynamic (`interpreter /lib64/ld-linux-x86-64.so.2`, newest symbol `GLIBC_2.16`
on x86_64; `/lib/ld-linux-aarch64.so.1`, `GLIBC_2.28` on aarch64 — the floors
are not symmetric, which is why each arch is measured separately). They are
deliberately **not** declared: the static build covers both userlands, so one
artifact per arch does the job of two. Adding `linux/<arch>+libc.glibc` later
is strictly additive — matching is subset-based and specificity-scored, so a
glibc host would simply start preferring the gnu build.

The `alpine:3.20` container leg on **both** arches is what turns the bare keys'
universality claim into evidence.

### Deliberately not carried

Upstream publishes 39 assets per release. Beyond the eight `-gnu` Linux
tarballs above, these have no OCX platform key at all — the `Architecture` enum
is amd64 + arm64 only:

```
prek-arm-unknown-linux-musleabihf.tar.gz          armv6-class
prek-armv7-unknown-linux-{gnueabihf,musleabihf}.tar.gz
prek-i686-unknown-linux-{gnu,musl}.tar.gz         32-bit x86
prek-i686-pc-windows-msvc.zip                     32-bit x86
prek-riscv64gc-unknown-linux-gnu.tar.gz
prek-s390x-unknown-linux-gnu.tar.gz               IBM Z
```

Plus the cargo-dist noise set: a `.sha256` sidecar beside **every** real asset,
`sha256.sum`, `dist-manifest.json`, `prek-installer.sh`, `prek-installer.ps1`,
`prek.rb` and `source.tar.gz`. End-anchoring is what keeps them out, and it is
mandatory rather than stylistic — an unanchored pattern matches an asset *and*
its `.sha256` twin and fails resolution as ambiguous.

⚠️ **The filenames carry no version string.** `prek-x86_64-unknown-linux-musl.tar.gz`
is identical as a name across every tag, so a name check can never catch an
upstream that republished the previous build under a new tag. Two things were
verified instead: every `browser_download_url` is tag-scoped
(`/releases/download/v0.4.10/…` vs `…/v0.4.12/…`, different sizes), and each
downloaded binary self-reports its own tag (`prek --version` → `prek 0.4.10`
and `prek 0.4.12`).

## Archive layout and the binaries claim

The two archive families differ, and `tar tvf` / `unzip -l` on every declared
asset of v0.4.10 and v0.4.12 is what decided the setting:

```
prek-<triple>.tar.gz  →  prek-<triple>/          wrapper dir
                         prek-<triple>/prek      0755, the only file
prek-<triple>.zip     →  prek.exe                FLAT — no wrapper at all
```

So the tarballs get `strip_components: 1` and the zips get `0`. Both land the
executable at the content root, which is why one `metadata.json` serves all six
platforms. Stripping the zips would delete `prek.exe` outright; keeping the
tarball wrapper would work but its name embeds the target triple, so it would
need a different metadata file per platform for no gain.

After extraction the bundle's only PATH entry is a bare `${installPath}`: the
executable *is* the content root. `bin_scan` only looks *below* an
`${installPath}/<dir>` entry, so `auto`/`verify` is rejected at spec load with
exit 65 (*the verification would inspect no file and pass green whatever the
archive contains*). `prek/mirror.yml` therefore sets `bin_scan: "off"` and
`prek/metadata.json` hand-lists `binaries: ["prek"]` — the blessed shape for
this layout, and `prek` is the archive's only entry.

## git is a runtime dependency, and the container legs provision it

prek is a Git hook manager: `prek list` and `prek run` shell out to
`git rev-parse --show-toplevel` as their first act and exit 2 without it.
`os.features` can express libc and nothing else, so that requirement has no
declarable home in the spec — `containers[].setup` in `mirror-base.yml` records
it instead. Measured: **none** of `ubuntu:24.04`, `alpine:3.20` or `fedora:40`
ships git, and all three run as uid 0, so each leg installs it in one line
(`apt-get install -y --no-install-recommends git` / `apk add --no-cache git` /
`dnf install -y git-core`). Each leg's honest claim is "runs on stock image X
plus git". Every GitHub-hosted macOS and Windows runner ships git already.

Consumers need the same thing: `ocx install ocx.sh/prek/prek` gives you the
binary, and a `git` on `PATH` is on you. That gap is a known limitation of the
mirror schema, not an oversight here.

## The smoke test is hermetic by construction

prek's headline feature — cloning hook repositories and provisioning language
runtimes — touches the network on every path. `prek/tests/smoke.star` avoids all
of it: the config it writes declares `repo: local` hooks with
`language: system`, which prek executes directly with no clone, no environment
build and no download, and `PREK_HOME` is pinned into the scratch sandbox so
nothing reads or writes a real user cache.

It asserts computed values, never prose or a bare exit 0:

- version **shape** (`\d+\.\d+\.\d+`), not the banner;
- `prek list` returns **exactly two** lines for a two-hook config — a count
  prek had to derive by parsing, where a listing that silently found zero hooks
  would still exit 0;
- `prek run --all-files` exits **1** with `repo-root-known…Passed` and
  `absent-ref…Failed` — two `repo: local` hooks with deterministic, opposite
  outcomes in any repository, so the verdicts come from real child-process exit
  codes and from nothing else;
- a **negative control**: a config whose hook omits the required `name` field
  is structurally valid YAML, so only prek's own schema layer can reject it —
  and the assertion is not exit 1 but the `<input>:4:9` position prek *computed*
  for the offending node plus the field name it worked out was missing. Neither
  string appears in the script's inputs.

Both halves were run locally against real v0.4.10 and v0.4.12 bundles, and the
whole sequence was re-run inside bare `ubuntu:24.04`, `alpine:3.20` and
`fedora:40` containers against the static musl binary before any of it was
pushed.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `mirror-base.yml`, `prek/mirror.yml` | hand | yes — see below |
| `prek/{metadata.json,CATALOG.md,logo.*}` | hand | — |
| `prek/tests/smoke.star` | hand | — |
| `.github/workflows/*.yml` | **generated — never hand-edit** | re-run when a spec changes |

```bash
ocx-mirror package pipeline generate ci --spec prek/mirror.yml
```

**Name every spec.** `--spec` *appends* rather than replaces, so a command
naming a subset silently stops rendering the rest while staying green — and the
drift guard reds on a generated workflow the current spec set no longer
produces.

`verify-generated.yml` exits 65 on drift. If a generated workflow is wrong, the
spec or the renderer template is wrong — fix it there and regenerate.

Run `direnv allow` once to put the pinned toolchain on `PATH`, and invoke
`ocx-mirror` directly — never `ocx run -- ocx-mirror`, which pins
`OCX_BINARY_PIN` to the bootstrap `ocx` and false-reds the nested push.

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index pull request from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

(Inherited from the `ocx-contrib` org with visibility ALL. GHCR pushes use the
run's own `GITHUB_TOKEN` — no registry secret needed.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of scope; the
redistribution license is recorded in [`NOTICE.md`](NOTICE.md).
