# StataNow19 Challenge Status

Current stage: license path validated; StataNow19 accepts dated licenses but rejects empty-date perpetual ones.

Confirmed facts:
- Candidate artifact: `artifacts/original/StataNow19Linux64.tar.gz`
- Source file from Downloads: `~/Downloads/StataNow19Linux64.tar.gz`
- File size at intake: `734M`
- SHA-256: `5f5691a312528152c910302e05f7fb05b2d8f8310780e435b105cd01edd763a3`
- Top-level tar layout currently matches the earlier Stata18 family at a high level:
  - `./install`
  - `./license.pdf`
  - `./unix/linux64/ado.taz`
  - `./unix/linux64/base.taz`
  - `./unix/linux64/bins.taz`
  - `./unix/linux64/docs.taz`
  - `./unix/linux64/inst2`
  - `./unix/linux64/setrwxp`
- A lightweight extraction of the installer scripts has already been performed into:
  - `artifacts/linuxpkg/install`
  - `artifacts/linuxpkg/unix/linux64/inst2`
  - `artifacts/linuxpkg/unix/linux64/setrwxp`
- `install` differs from the archived Stata18 version in these visible ways:
  - version banner changed from `18.0.0` to `19.5.0`
  - branding changed from `Stata 18` to `StataNow 19.5`
  - recommended install directories now include `/usr/local/stata19` and `/usr/local/statanow19`
  - marker file changed from `installed.180` to `installed.195`
  - a new guard blocks installation on top of an existing `installed.190` Stata 19 tree
- `inst2` mirrors the same shift:
  - version banner changed to `19.5.0`
  - branding changed to `StataNow 19.5`
  - it now writes both `installed.195` and `installed.190`
- `setrwxp` does not match the new branding cleanly:
  - header still says `Stata 19` / `19.0.0`
  - it refers to `st19` and `stata19.png`
- A streamed listing of `bins.taz` currently shows:
  - `stinit`
  - `libstata.so`, `libstata-se.so`, `libstata-mp.so`
  - `stata`, `stata-se`, `stata-mp`
  - `xstata`, `xstata-se`, `xstata-mp`
- The same `bins.taz` listing did not show:
  - `st19`
  - `stata19.png`
  - `isstata.19*`
- A full isolated install from the original `install` script now exists at:
  - `runtime/statanow19-local-b`
- The normalized local launcher install at `~/.local/opt/stata-mp` has now been switched over to the StataNow19 runtime:
  - the old local runtime was preserved as `~/.local/opt/stata-mp/runtime.stata18-backup-20260326`
  - `~/.local/bin/stata-mp` now starts `StataNow 19.5` successfully with the default `64-core` / `01012050` profile
  - `~/.local/share/applications/stata-mp.desktop` now uses the `stata19.png` icon
  - the local install has since been made self-contained:
    - `~/.local/opt/stata-mp/runtime` is now a real copied directory, not a symlink
    - `~/.local/opt/stata-mp/lib/ncurses6` is now a real copied directory, not a symlink
- The static operator page at `../stata18-toolkit/tools/license_lab.html` has been rebuilt around the Stata 19 defaults:
  - default preset is now `MP 64-core`
  - default date is now `01012050`
  - the Linux usage path now points at `~/.local/opt/stata-mp/runtime/stata.lic`
- The installed runtime tree contains:
  - `installed.190`
  - `installed.195`
  - `isstata.195`
  - `stata19.png`
- The `stinit` binary in `StataNow19` is byte-identical to the archived `Stata18` `stinit`:
  - same size
  - same SHA-256
- Therefore the `Serial number` / `Code` / `Authorization` transform and `stata.lic` file format remain unchanged.
- A minimal local ncurses6 shim now lives at:
  - `runtime/localdeps/ncurses6/libncurses.so.6`
  - `runtime/localdeps/ncurses6/libtinfo.so.6`
- The `Stata18` generator logic still works against `StataNow19` if used with:
  - split prefix `4`
  - the same base-37 encoding
  - the same `serial!code!authorization!line1!line2!sum!` on-disk `stata.lic` format
- The key runtime behavior change found so far is:
  - empty `field6` date => `License not applicable to StataNow`
  - past `field6` date => license class is recognized and shown as expired
  - current/future-near `field6` date => runtime starts successfully
- Refined `field6` behavior from isolated serial scans:
  - the live-date boundary is inclusive of the current host date `2026-03-26`
  - `03252026` is expired, while `03262026` starts successfully
  - far-future dates are not open-ended: `2050` is still accepted, but `2051+` is rejected as `License is invalid`
  - malformed 8-digit dates are not rejected consistently:
    - `00000000` shows `expiring  invld date` and is treated as expired
    - `13312026` shows `expiring  invld date` but still starts
    - `02292027` and `02302026` are displayed literally rather than calendar-validated
- Refined `field7` behavior for `stata-mp`:
  - empty or nonnumeric values are rejected as `License not applicable to this Stata`
  - leading-zero numeric forms are accepted numerically, for example `002` => `2-core`, `064` => `64-core`
  - `0` and `1` are rejected
  - `2..64` are accepted directly
  - values above `64` start successfully but are clamped in the banner to `64-core`
- Known-good dated examples:
  - BE payload: `12345678$999$24$5$9999$h$03272026`
  - MP payload: `12345678$999$24$5$9999$h$03272026$32`
- These produce working startup banners such as:
  - `Stata license: Unlimited-student lab, expiring 27 Mar 2026`
  - `Stata license: Unlimited-student 32-core lab, expiring 27 Mar 2026`

Interpretation:
- `StataNow19Linux64.tar.gz` is structurally close enough to the previous Stata18 package that the same installer-intake workflow is likely reusable.
- The installer chain is not a pure cosmetic rename: `install`/`inst2` understand both `19.0` and `19.5` marker files and contain explicit coexistence logic for `Stata 19` versus `StataNow 19.5`.
- `setrwxp` appears to lag the rest of the chain, or to preserve compatibility naming that is not obviously present in the streamed `bins.taz` file list.
- The license transform itself does not appear to be the novelty: `stinit` is identical and the old code/authorization generator still produces decodable licenses.
- The meaningful runtime delta is policy-level: `StataNow19` no longer accepts the old empty-date perpetual family, but it does accept the same family once `field6` carries a live expiration date.
- The date policy is now better defined: nonempty `field6` must be 8 characters, the effective upper year bound appears to be `2050`, and malformed in-range dates are only partially validated.
- The MP-core policy is now mostly defined at the runtime surface: the accepted integer range is `2..64`, while larger numeric strings are clamped to `64`.
- The user-facing local install has been normalized onto the StataNow19 tree without touching system packages: command names stay the same, while the wrappers now emit a dated `field6` license and use `ncurses6`.
- That local install is now also self-contained under `~/.local/opt/stata-mp`, so daily use no longer depends on the challenge workspace runtime via symlinked paths.
- The Stata18 effort has been snapshotted separately in `../stata18-toolkit/docs/human/ARCHIVE_STATA18_2026-03-26_STATUS.md` and related archive files.

Primary references:
- `artifacts/intake/top_level_listing.txt`
- `artifacts/linuxpkg/install`
- `artifacts/linuxpkg/unix/linux64/inst2`
- `artifacts/linuxpkg/unix/linux64/setrwxp`
- `runtime/statanow19-local-b/stata.lic`
- `runtime/localdeps/ncurses6/libncurses.so.6`
- `docs/human/CHALLENGE_REPORT.md`

## 2026-04-03 Delivery Snapshot

- 最终交付物已经落在 `delivery/`，而不是 `~/.local/opt/stata-mp` 这类本地验证目录。
- 交付结构固定为：
  - `delivery/license-builder/statanow19-license-builder.py`
  - `delivery/archpkg/statanow19-runtime/PKGBUILD`
  - `delivery/archpkg/statanow19-runtime/statanow19-runtime-19.5.0-1-x86_64.pkg.tar.zst`
- 本地安装只用于验证 StataNow19 dated-license 路径和依赖内置方案，不作为最终交付产物。
- `delivery/archpkg/statanow19-runtime/` 内已包含 launcher、desktop entry、sample config、GTK2 主题和打包所需 runtime 模板。

## 2026-04-03 GitHub Release CI

- 已新增 GitHub Actions 发布流：`.github/workflows/release.yml`。
- 发布流会从 Duke 下载 `StataNow19Linux64.tar.gz`，校验 SHA-256，然后在 Arch Linux 容器内构建 `statanow19-runtime`。
- Release 资产现在规划为：构建出的 `.pkg.tar.zst`、版本化 builder 脚本、`SHA256SUMS.txt`、`BUILD-INFO.txt`。
- 仓库本身不应再提交上游 tarball、运行时工作目录或最终 `.pkg.tar.zst`。

## 2026-04-03 GitHub Publication

- 源码仓库已发布到：
- 首次推送只保留源码、文档和 CI/CD 配置；本地生成物与上游二进制未进入 git。
- 仓库内不再依赖本地 ；提交使用一次性环境变量完成。
- 下一步应直接在 GitHub 上执行一次 ，确认 Release 资产能完整产出。
