# StataNow19 Reverse-Engineering Notes

## Intake

A new package candidate was found in Downloads:

- `~/Downloads/StataNow19Linux64.tar.gz`

Initial intake results:

- file size: `734M`
- SHA-256: `5f5691a312528152c910302e05f7fb05b2d8f8310780e435b105cd01edd763a3`
- copied into workspace as:
  - `artifacts/original/StataNow19Linux64.tar.gz`

Top-level tar listing:

- `./install`
- `./license.pdf`
- `./unix/linux64/ado.taz`
- `./unix/linux64/base.taz`
- `./unix/linux64/bins.taz`
- `./unix/linux64/docs.taz`
- `./unix/linux64/inst2`
- `./unix/linux64/setrwxp`

At this point the package shape looks like a close relative of the earlier Stata18 Linux distribution.

## Installer-chain comparison

Three installer-side scripts were extracted without unpacking the full runtime payload:

- `artifacts/linuxpkg/install`
- `artifacts/linuxpkg/unix/linux64/inst2`
- `artifacts/linuxpkg/unix/linux64/setrwxp`

Observed differences relative to the archived Stata18 package:

- `install`
  - version changed from `18.0.0` to `19.5.0`
  - visible branding changed to `StataNow 19.5`
  - recommended directories now include `/usr/local/stata19` and `/usr/local/statanow19`
  - primary marker changed from `installed.180` to `installed.195`
  - a new branch rejects installing `StataNow 19.5` on top of an existing `installed.190` Stata 19 tree
- `inst2`
  - version changed from `18.0.0` to `19.5.0`
  - visible branding changed to `StataNow 19.5`
  - it now writes both `installed.195` and `installed.190`
- `setrwxp`
  - header still says `Stata 19` / `19.0.0`
  - still refers to `st19` and `stata19.png`

That last point does not line up cleanly with the first streamed `bins.taz` listing.

## Runtime-name listing from `bins.taz`

A streamed file-name listing from `unix/linux64/bins.taz` confirmed these entries:

- `stinit`
- `libstata.so`
- `libstata-se.so`
- `libstata-mp.so`
- `stata`
- `stata-se`
- `stata-mp`
- `xstata`
- `xstata-se`
- `xstata-mp`

The same listing did not show:

- `st19`
- `stata19.png`
- `isstata.19*`

This suggests either:

- `setrwxp` preserves stale compatibility naming from an earlier packaging revision, or
- those files live outside `bins.taz`, or
- the runtime tree is assembled differently than the first script read implies

The next useful step is to inspect `stinit` and the runtime payload directly.

## License-path validation

An isolated install was then performed from the original media into:

- `runtime/statanow19-local-b`

Important on-disk results from that install:

- `installed.190`
- `installed.195`
- `isstata.195`
- `stata19.png`

This resolves the earlier apparent mismatch: the streamed `bins.taz` listing did not show those names, but the final installed tree does contain at least some of them.

### `stinit` result

`stinit` from the installed StataNow19 tree is byte-identical to the archived Stata18 `stinit`.

That means:

- the `Serial number` / `Code` / `Authorization` transform is unchanged
- the `stata.lic` on-disk format is unchanged
- split-prefix `4` is still the runtime-correct write format

### Runtime behavior delta

The console runtime now links against:

- `libncurses.so.6`
- `libtinfo.so.6`

A minimal local shim was staged under:

- `runtime/localdeps/ncurses6/libncurses.so.6`
- `runtime/localdeps/ncurses6/libtinfo.so.6`

so the new runtime could be exercised without touching system packages.

Using the existing generator from the archived Stata18 work:

- tool: `../stata18-toolkit/tools/license_probe.py`

the following behavior was observed:

- empty `field6`:
  - `12345678$999$24$5$9999$h$`
  - result: `License not applicable to StataNow`
- past `field6`:
  - `12345678$999$24$5$9999$h$01012020`
  - result: runtime recognizes the class and shows `expiring  1 Jan 2020`
- current / near-future `field6`:
  - `12345678$999$24$5$9999$h$03272026`
  - result: runtime starts successfully

So the most important license difference discovered so far is:

- `Stata18`: empty-date perpetual family was accepted
- `StataNow19`: empty-date perpetual family is rejected as not applicable
- `StataNow19`: the same family becomes valid once `field6` carries a live expiration date

### Known-good dated examples

BE:

- payload: `12345678$999$24$5$9999$h$03272026`
- generated `stata.lic`: `12345678!teu235zjv7ipx$3zlz39zpf2o2fs27hm!cb82!LocalLab!LocalLab!1524!`
- displayed text: `Stata license: Unlimited-student lab, expiring 27 Mar 2026`

MP:

- payload: `12345678$999$24$5$9999$h$03272026$32`
- generated `stata.lic`: `12345678!bxclmoh1dq07fimh3hmsh7yl6lyalqwz$1y!vurl!LocalLab!LocalLab!1524!`
- displayed text: `Stata license: Unlimited-student 32-core lab, expiring 27 Mar 2026`

This is strong evidence that the old generator remains usable, but the policy for acceptable payloads has shifted from perpetual licensing to dated licensing.

## Date-window refinement

The earlier “dated licenses work” result was then re-run in isolated and serial form to remove cross-test contamination from repeated writes to the same `stata.lic`.

With the host date at `2026-03-26`, the refined behavior is:

- empty `field6`
  - payload: `12345678$999$24$5$9999$h$`
  - result: `License not applicable to StataNow`
- previous day
  - payload: `12345678$999$24$5$9999$h$03252026`
  - result: shown as `expiring 25 Mar 2026`, then rejected as expired
- current day
  - payload: `12345678$999$24$5$9999$h$03262026`
  - result: startup succeeds
- future in-range dates
  - `03312026`, `12312050`
  - result: startup succeeds
- future out-of-range years
  - `12312051`, `12312058`, `12312099`, `01012100`
  - result: `License is invalid`

This strongly suggests an effective upper bound of year `2050`, inclusive.

Malformed eight-character dates are not handled uniformly:

- `00000000`
  - displayed as `expiring  invld date`
  - then treated as expired
- `13312026`
  - displayed as `expiring  invld date`
  - startup still succeeds
- `02302026`
  - displayed literally as `30 Feb 2026`
  - then treated as expired
- `02292027`
  - displayed literally as `29 Feb 2027`
  - startup succeeds

So the runtime is not doing strict calendar validation for all cases. The date gate appears to be a mix of fixed-format acceptance, a year-range constraint, and a looser expiry/applicability check.

## MP-core refinement

The MP-specific suffix `field7` was then mapped against `stata-mp`.

Confirmed runtime behavior:

- `0` and `1`
  - result: `License not applicable to this Stata`
- `2..64`
  - result: accepted directly and shown literally in the banner
- `65`, `66`, `96`, `128`
  - result: startup succeeds, but the banner is clamped to `64-core`
- empty suffix
  - payload shape: `...$03272026$`
  - result: `License not applicable to this Stata`
- nonnumeric suffix
  - payload shape: `...$03272026$abc`
  - result: `License not applicable to this Stata`
- numeric strings with leading zeros
  - `002` => `2-core`
  - `064` => `64-core`

At the runtime surface, the MP rule is now close to fully mapped:

- parse a decimal-like integer suffix
- reject values below `2`
- accept `2..64`
- clamp larger numeric values to `64`

## Normalized local install switch

After the runtime behavior was mapped, the normalized user-local launcher tree was switched from the old Stata18 payload to the validated StataNow19 runtime without touching system packages.

Applied local changes:

- `~/.local/opt/stata-mp/runtime`
  - moved aside the old directory as `runtime.stata18-backup-20260326`
  - initially repointed `runtime` to `~/ctf/statanow19-toolkit/runtime/statanow19-local-b`
  - later copied that runtime in place so `runtime` is now a real local directory again
- `~/.local/opt/stata-mp/lib/ncurses6`
  - initially linked to `~/ctf/statanow19-toolkit/runtime/localdeps/ncurses6`
  - later copied in place so `lib/ncurses6` is now a real local directory again
- `~/.local/opt/stata-mp/bin/stata-mp`
  - switched from `ncurses5` to `ncurses6`
  - changed the default payload from empty-date MP 32 to dated MP 64
  - default profile is now `STATA_MP_CORES=64` and `STATA_EXPIRY=01012050`
- `~/.local/opt/stata-mp/bin/xstata-mp`
  - switched to the same dated-license and `ncurses6` defaults
- `~/.config/stata-mp/config.env`
  - now pins `STATA_MP_CORES=64`
  - now pins `STATA_EXPIRY=01012050`
- `~/.local/share/applications/stata-mp.desktop`
  - renamed the entry to `Stata 19 MP`
  - switched the icon to `stata19.png`

Verification result:

- `~/.local/bin/stata-mp` now starts as:
  - `StataNow 19.5`
  - `MP—Parallel Edition`
  - `Stata license: Unlimited-student 64-core lab, expiring 1 Jan 2050`

The GUI launcher path was also smoke-tested outside the sandbox. No immediate launcher-side dependency or theme error was observed during the short launch window.

At this point the normalized local install is self-contained again:

- command entrypoints still live under `~/.local/bin/`
- the actual app tree now lives under `~/.local/opt/stata-mp/`
- normal day-to-day launching no longer depends on `~/ctf/statanow19-toolkit/runtime/...` through symlinks

## Static HTML tool refresh

The single-file operator tool at:

- `../stata18-toolkit/tools/license_lab.html`

was rebuilt after an earlier failed write left it empty.

Current tool shape:

- defaults to the validated Stata 19 family rather than the old Stata18-style perpetual defaults
- primary preset is now `MP 64-core`
- default date is `01012050`
- outputs:
  - `Serial number`
  - `Code`
  - `Authorization`
  - `stata.lic`
- Linux usage text now points to the normalized local path:
  - `~/.local/opt/stata-mp/runtime/stata.lic`

The page keeps the same offline model:

- single HTML file
- no backend
- local generation only

## Delivery Packaging

Final operator-facing outputs for the StataNow 19 branch now live under `delivery/`:

- `delivery/license-builder/statanow19-license-builder.sh`
  - standalone versioned builder for installer-style `Serial number` / `Code` / `Authorization` generation
- `delivery/archpkg/statanow19-runtime/PKGBUILD`
  - Arch packaging recipe for a self-contained runtime install under `/opt/statanow19-runtime`
- `delivery/archpkg/statanow19-runtime/statanow19-runtime-19.5.0-1-x86_64.pkg.tar.zst`
  - built package artifact

The package layout intentionally treats the earlier `~/.local/opt/stata-mp` installation as validation-only. The final package instead ships:

- bundled runtime template
- bundled GTK2 libraries
- bundled versioned license builder CLI
- launcher wrappers for console and GUI entry points
- per-user writable runtime materialized under `~/.local/state/statanow19-runtime/runtime`
- per-user config under `~/.config/statanow19-runtime/config.env`

## GitHub Release Automation

A repository-facing release path now exists alongside the local packaging work. The new workflow at `.github/workflows/release.yml` runs on tags or manual dispatch, downloads the upstream StataNow 19 media from Duke, verifies the known SHA-256, stages GTK2 libraries from an Arch environment, builds the package with `makepkg`, and publishes the resulting release assets through GitHub Releases.

The PKGBUILD now accepts `GTK2_LIB_ROOT` overrides so CI does not depend on a sibling checkout of the Stata 18 workspace.
