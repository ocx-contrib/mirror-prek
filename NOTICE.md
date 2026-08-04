# NOTICE

This repository packages and redistributes upstream software published by the
[prek](https://github.com/j178/prek) project. The Apache-2.0 license in
[`LICENSE`](LICENSE) covers the OCX pipeline files authored here. It does
**not** cover any upstream-derived asset — the redistributed bytes carry their
own license, recorded below.

The package logo is upstream's own mark
([`docs/assets/logo.png`](https://github.com/j178/prek/blob/master/docs/assets/logo.png)),
re-encoded to 512×512 for catalog identification only. No endorsement is
implied.

| Package | GHCR path | Upstream SPDX |
|---|---|---|
| `prek` | `ghcr.io/ocx-contrib/prek/prek` | `MIT` |

---

## `prek`

Upstream: <https://github.com/j178/prek>
Published to `ghcr.io/ocx-contrib/prek/prek`.

| Component | SPDX | Holder |
|---|---|---|
| prek | **MIT** | j178 |

Verified at the Phase 1.5 license gate:

```
$ gh api repos/j178/prek/license --jq '{spdx: .license.spdx_id, path: .path}'
{"path":"LICENSE","spdx":"MIT"}
```

MIT is permissive and grants redistribution of the compiled binary subject to
its notice-retention condition. Upstream's release archives contain the
executable alone — verified with `tar tvf` on every declared asset of v0.4.10
and v0.4.12, exactly two entries each: the `prek-<triple>/` wrapper directory
and the `prek` executable inside it, no `LICENSE` file — so the notice is
retained here instead. The canonical text is
<https://github.com/j178/prek/blob/master/LICENSE>, and every published
manifest carries an `org.opencontainers.image.source` annotation pointing at
this repository, alongside `org.opencontainers.image.licenses: MIT`.

The published binaries are statically linked Rust builds that vendor
third-party crates under permissive licenses, enumerated in upstream's
`Cargo.lock` and `licenses/` tree.

No modifications are made to any upstream artifact in this repository; they are
republished byte-for-byte inside an OCX bundle.
