#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
pkg_dir="$repo_root/delivery/archpkg/statanow19-runtime"
dist_dir="$repo_root/dist"
ci_root="$repo_root/.ci"
stage_root="$ci_root/stage"
media_path="$repo_root/artifacts/original/StataNow19Linux64.tar.gz"
upstream_url="${UPSTREAM_URL:-https://public.econ.duke.edu/stata/installers/19/StataNow19Linux64.tar.gz}"
upstream_sha256="${UPSTREAM_SHA256:-5f5691a312528152c910302e05f7fb05b2d8f8310780e435b105cd01edd763a3}"

download_latest_archive_pkg() {
  local pkg="$1"
  local out="$2"
  local prefix=${pkg:0:1}
  local index_url="https://archive.archlinux.org/packages/$prefix/$pkg/"
  local filename

  filename=$(curl -fsSL "$index_url" | sed -nE "s/.*href=\"(${pkg}-[^\"]+-x86_64\\.pkg\\.tar\\.(zst|xz))\".*/\\1/p" | sort -uV | tail -n 1)
  [[ -n "$filename" ]] || {
    echo "Unable to resolve archived package for $pkg from $index_url" >&2
    return 1
  }

  curl -L --fail --retry 3 --retry-delay 2 "$index_url$filename" -o "$out"
}

extract_pkg_usr_lib_tree() {
  local pkg_file="$1"
  local dest_root="$2"
  local tmp_dir

  tmp_dir=$(mktemp -d)
  bsdtar -xf "$pkg_file" -C "$tmp_dir"
  install -d "$dest_root"
  cp -a "$tmp_dir/usr/lib/." "$dest_root/"
  rm -rf "$tmp_dir"
}

rm -rf "$dist_dir" "$stage_root" "$ci_root/work"
install -d "$(dirname "$media_path")" "$dist_dir" "$stage_root/gtk2/usr/lib" "$ci_root/work"

if [[ -f "$media_path" ]]; then
  current_sha=$(sha256sum "$media_path" | awk '{print $1}')
else
  current_sha=''
fi
if [[ "$current_sha" != "$upstream_sha256" ]]; then
  curl -L --fail --retry 3 --retry-delay 2 "$upstream_url" -o "$media_path"
fi
printf '%s  %s\n' "$upstream_sha256" "$media_path" | sha256sum -c -

gtk2_pkg="$ci_root/work/gtk2.pkg.tar.zst"
download_latest_archive_pkg gtk2 "$gtk2_pkg"
extract_pkg_usr_lib_tree "$gtk2_pkg" "$stage_root/gtk2/usr/lib"
install -m755 "$repo_root/delivery/license-builder/statanow19-license-builder.py" "$pkg_dir/statanow19-license-builder.py"

(
  cd "$pkg_dir"
  CHALLENGE_ROOT="$repo_root" \
  GTK2_LIB_ROOT="$stage_root/gtk2/usr/lib" \
  PKGDEST="$dist_dir" \
  SRCDEST="$ci_root/work/src" \
  BUILDDIR="$ci_root/work/build" \
  makepkg -Cfs --noconfirm
)

cp "$repo_root/delivery/license-builder/statanow19-license-builder.py" "$dist_dir/"
cat > "$dist_dir/BUILD-INFO.txt" <<EOF2
package=statanow19-runtime
source_url=$upstream_url
source_sha256=$upstream_sha256
built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF2
cat > "$dist_dir/RELEASE_NOTES.md" <<EOF2
## Build Inputs

- Package: \`statanow19-runtime\`
- Upstream media: <$upstream_url>
- Upstream SHA-256: \`$upstream_sha256\`

## Release Assets

- Built Arch package \`.pkg.tar.zst\`
- Versioned license builder \`statanow19-license-builder.py\`
- \`SHA256SUMS.txt\` and \`BUILD-INFO.txt\`
EOF2
(
  cd "$dist_dir"
  sha256sum ./* > SHA256SUMS.txt
)
