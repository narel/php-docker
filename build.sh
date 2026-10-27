#!/bin/bash
# ---------------------------------------------------------------------------
# Builds the PHP + Apache + mod_php images.
#
#   ./build.sh                    # all versions
#   ./build.sh 8.5 7.4            # selected versions only
#   PUSH=1 ./build.sh 8.5         # build and push
#   PLATFORM=linux/amd64 ./build.sh 5.3   # old base images are amd64 only
#   NO_PULL=1 ./build.sh 8.2      # do not refresh the base image
#   NO_CACHE=1 ./build.sh 8.5     # no layer cache - use after security fixes
#   BUILDER=oldbuilder ./build.sh 5.5     # build with the given buildx builder
#   ./build.sh --list             # print the available versions and exit
#
# --pull refreshes only the base image. If it has not changed, the apt-get
# layer comes from the cache and new packages from the repository do NOT
# reach the image.
#
# NOTE for PHP 5.x images: on recent kernels the default BuildKit hangs apt
# from the jessie/wheezy era (apt-get update spins forever at 100% CPU).
# Workaround - create, once, a builder that runs an older BuildKit:
#
#   docker buildx create --name oldbuilder --driver docker-container \
#       --driver-opt image=moby/buildkit:v0.12.5
#   BUILDER=oldbuilder ./build.sh 5.5 5.4 5.3 5.2
#
# A failure in one version does not stop the others. A summary is printed at
# the end, and the exit code is non-zero if anything failed.
# ---------------------------------------------------------------------------
set -uo pipefail

REGISTRY="${REGISTRY:-narel/php}"
PUSH="${PUSH:-}"
PLATFORM="${PLATFORM:-}"
NO_PULL="${NO_PULL:-}"
NO_CACHE="${NO_CACHE:-}"
BUILDER="${BUILDER:-}"

# version | dockerfile | base image | imap | required PECL | optional PECL | extra tags | PHP repo
#
# imap: apt = apt package (distribution or Sury), pecl = built from PECL
# (since 8.4 imap is no longer part of PHP core; on trixie libc-client comes
# from bookworm), none = no imap.
#
# PECL versions are pinned on purpose: mongodb has a hard PHP minimum
# (2.5.x >= 8.1, 1.20.x >= 7.4, 1.11.x >= 7.1, 1.9.x >= 7.0), and an unpinned
# `pecl install mongodb` silently failed to install on 7.2/7.4.
# rar is optional - it does not compile on 8.x at all:
# https://github.com/cataphract/php-rar/issues/17
#
# PHP repo: empty = distribution, sury = packages.sury.org. 7.4 and 5.6 come
# from Sury, the only free source of fixes for CVE-2026-109618/109619.
VERSIONS="
8.5|Dockerfile|ubuntu:26.04|pecl|mongodb-2.5.2||8
8.4|Dockerfile|debian:trixie|pecl|mongodb-2.5.2||
8.2|Dockerfile|debian:bookworm|apt|mongodb-2.5.2||
8.1|Dockerfile|ubuntu:22.04|apt|mongodb-2.5.2||
7.4|Dockerfile|debian:trixie|apt|mongodb-1.20.1|rar-4.2.0|7|sury
7.4-mongodb1.18|Dockerfile.php7.4-mongodb1.18|||||
7.2|Dockerfile|ubuntu:18.04|apt|mongodb-1.11.1|rar-4.2.0|
7.0|Dockerfile|ubuntu:16.04|apt|mongodb-1.9.2|rar-4.2.0|
5.6|Dockerfile|debian:trixie|apt|mongodb-1.7.4|rar-4.2.0|5|sury
5.5|Dockerfile.php5.5|||||
5.4|Dockerfile.php5.4|||||
5.3|Dockerfile.php5.3|||||
5.2|Dockerfile.php5.2|||||
"

all_versions() { echo "$VERSIONS" | grep -v '^[[:space:]]*$' | cut -d'|' -f1; }

find_entry() {
    echo "$VERSIONS" | grep -v '^[[:space:]]*$' | awk -F'|' -v v="$1" '$1 == v {print; exit}'
}

build_one() {
    local entry ver dockerfile base imap req opt tags repo
    entry="$(find_entry "$1")"
    if [ -z "$entry" ]; then
        echo "!! unknown version: $1 (available: $(all_versions | tr '\n' ' '))" >&2
        return 1
    fi
    IFS='|' read -r ver dockerfile base imap req opt tags repo <<<"$entry"

    echo
    echo "################ PHP ${ver} ################"

    local args
    if [ -n "$BUILDER" ]; then
        args=(buildx build --builder "$BUILDER" --load)
    else
        args=(build)
    fi
    args+=(--file "$dockerfile" --tag "${REGISTRY}:${ver}")
    [ -z "$NO_PULL" ] && args+=(--pull)
    [ -n "$NO_CACHE" ] && args+=(--no-cache)
    [ -n "$PLATFORM" ] && args+=(--platform "$PLATFORM")
    if [ -n "$base" ]; then
        args+=(--build-arg "BASE_IMAGE=${base}"
               --build-arg "PHP_VER=${ver}"
               --build-arg "IMAP=${imap}"
               --build-arg "PECL_REQUIRED=${req}"
               --build-arg "PECL_OPTIONAL=${opt}"
               --build-arg "PHP_REPO=${repo}")
        case "$ver" in
            # no fixes for CVE-2026-109618/109619 - every request runs in a
            # fresh process. Legacy 5.x images set this in their own Dockerfiles.
            7.0|7.2) args+=(--build-arg "APACHE_KEEPALIVE=Off"
                            --build-arg "APACHE_MAX_REQUESTS_PER_CHILD=1") ;;
            # what the old Debian 8 based 5.6 image had and the shared
            # Dockerfile does not install. GCC 14 treats incompatible pointer
            # types as an error; in rar-4.2.0 on PHP 5.6 they differ only in const.
            5.6) args+=(--build-arg "EXTRA_PACKAGES=php5.6-bz2 php5.6-dba php5.6-mcrypt"
                        --build-arg "PEAR_PACKAGES=XML_Parser-1.3.8 XML_RPC-1.5.5 XML_DTD-0.5.2"
                        --build-arg "APACHE_EXTRA_MODS=ssl"
                        --build-arg "PECL_CFLAGS=-g -O2 -Wno-error=incompatible-pointer-types") ;;
        esac
    fi
    args+=(.)

    ( set -x; docker "${args[@]}" ) || return 1

    for t in $tags; do
        ( set -x; docker tag "${REGISTRY}:${ver}" "${REGISTRY}:${t}" ) || return 1
    done

    if [ -n "$PUSH" ]; then
        ( set -x; docker push "${REGISTRY}:${ver}" ) || return 1
        for t in $tags; do
            ( set -x; docker push "${REGISTRY}:${t}" ) || return 1
        done
    fi
}

if [ "${1:-}" = "--list" ]; then
    all_versions
    exit 0
fi

if [ "$#" -gt 0 ]; then
    targets=("$@")
else
    mapfile -t targets < <(all_versions)
fi

ok=() failed=()
for v in "${targets[@]}"; do
    if build_one "$v"; then ok+=("$v"); else failed+=("$v"); fi
done

echo
echo "======================= SUMMARY ========================"
[ "${#ok[@]}"     -gt 0 ] && echo "OK:     ${ok[*]}"
[ "${#failed[@]}" -gt 0 ] && echo "FAILED: ${failed[*]}"
echo "========================================================"
[ "${#failed[@]}" -eq 0 ]
