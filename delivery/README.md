# StataNow 19 Deliverables

最终交付物：
- `license-builder/`：版本化 license 生成器
- `archpkg/statanow19-runtime/`：Arch 包构建目录

## GitHub Release CI

- Workflow: `.github/workflows/release.yml`
- Build entrypoint: `scripts/ci/build-release.sh`
- CI downloads the upstream installer from Duke, verifies SHA-256, builds the Arch package inside an Arch Linux container, and uploads the package plus the builder script to GitHub Releases.
- The repository should keep scripts and metadata in git, while the upstream media and built `.pkg.tar.zst` stay out of git and are published as release assets.
