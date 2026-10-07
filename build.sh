#!/bin/sh
#
# Cached build wrapper for the Sophgo SG200x Debian images.
#
# A plain `docker run --rm` throws away the whole build tree every time, so the
# kernel/osdrv/middleware/buildroot are re-cloned and re-compiled, the rootfs is
# rebuilt and the ~1 GB of cross toolchains are re-downloaded. This wrapper keeps
# that state in named volumes instead:
#
#   sg200x-build-<board>-<variant>-<storage>-<second_cpu>-<arch>-<gitref>  -> /build
#   sg200x-rootfs-<...>                                                   -> /rootfs
#   sg200x-host-tools                                                     -> /host-tools
#   sg200x-apt                                                            -> /var/cache/apt
#
# The build/rootfs volumes are scoped to the configuration (the build system is
# not safe to share one /build between different boards/personalities). The
# toolchain and apt volumes are shared.
#
# Image personalisation (`IMAGE_HOSTNAME`, `WIFI_*`, ...) does not change the
# compiled sources, but the make stamps do not track those values. So for
# `image` builds this wrapper remembers the make variables per config and, when
# they change, prepends `image-clean` so the requested configuration is actually
# baked in. Use --refresh to force it, --no-refresh to disable it.
#
# Usage:
#   ./build.sh BOARD=oz64 SECOND_CPU=arduino IMAGE_HOSTNAME=oz64-toad image
#   ./build.sh BOARD=oz64 SECOND_CPU=arduino dtbs         # DTBs only, no kernel compile
#   ./build.sh BOARD=oz64 linux-clean                     # drop the kernel tree
#   ./build.sh --clean BOARD=oz64 image                   # wipe this config's cache
#   ./build.sh --purge BOARD=oz64 image                   # also wipe toolchains + apt
#
# NOTE: the stamps do not track config file contents either, so after editing
# configs/ you must drop the affected stage (e.g. `linux-clean`, `osdrv-clean`,
# `buildroot-clean`) or use --clean.
#
# Environment:
#   DOCKER  container engine (default: docker)
#   IMAGE   builder image      (default: builder)
#   PREFIX  volume name prefix (default: sg200x)
set -e

DOCKER=${DOCKER:-docker}
IMAGE=${IMAGE:-builder}
PREFIX=${PREFIX:-sg200x}

REPO_DIR=$(cd "$(dirname "$0")" && pwd)

clean=false
purge=false
refresh=auto
while [ $# -gt 0 ]; do
	case "$1" in
		--clean) clean=true; shift ;;
		--purge) clean=true; purge=true; shift ;;
		--refresh) refresh=yes; shift ;;
		--no-refresh) refresh=no; shift ;;
		--help|-h)
			sed -n '2,/^set -e/p' "$0" | sed 's/^# \{0,1\}//'
			exit 0 ;;
		*) break ;;
	esac
done

if [ $# -eq 0 ]; then
	echo "usage: $0 [--clean|--purge|--refresh|--no-refresh] make-args..." >&2
	exit 1
fi

board= variant=e storage=sd second=camera arch=riscv gitref=develop
has_image=false
for a in "$@"; do
	case "$a" in
		BOARD=*)       board=${a#BOARD=} ;;
		VARIANT=*)     variant=${a#VARIANT=} ;;
		STORAGE_TYPE=*) storage=${a#STORAGE_TYPE=} ;;
		SECOND_CPU=*)  second=${a#SECOND_CPU=} ;;
		ARCH=*)        arch=${a#ARCH=} ;;
		GIT_REF=*)     gitref=${a#GIT_REF=} ;;
		image)         has_image=true ;;
	esac
done
if [ -z "$board" ]; then
	echo "error: BOARD=<board> is required" >&2
	exit 1
fi

key="$board-$variant-$storage-$second-$arch-$gitref"
build_vol="$PREFIX-build-$key"
rootfs_vol="$PREFIX-rootfs-$key"
hosttools_vol="$PREFIX-host-tools"
apt_vol="$PREFIX-apt"

# Fingerprint of the make variables (KEY=VALUE args); used to detect
# image-personalisation changes that the make stamps cannot see.
fingerprint=$(for a in "$@"; do case "$a" in *=*) printf '%s\n' "$a" ;; esac; done)
state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/sg200x"
state_file="$state_dir/$key.vars"

if $clean; then
	echo ">>> removing cached build/rootfs for $key"
	$DOCKER volume rm -f "$build_vol" "$rootfs_vol" >/dev/null 2>&1 || true
fi
if $purge; then
	echo ">>> removing cached toolchains and apt cache"
	$DOCKER volume rm -f "$hosttools_vol" "$apt_vol" >/dev/null 2>&1 || true
fi

do_refresh=false
case "$refresh" in
	yes) do_refresh=true ;;
	auto)
		if $has_image && [ -f "$state_file" ] && \
		   [ "$(cat "$state_file" 2>/dev/null)" != "$fingerprint" ]; then
			do_refresh=true
			echo ">>> image config changed; refreshing image assembly (image-clean)"
		fi ;;
esac

if $has_image; then
	mkdir -p "$state_dir" 2>/dev/null || true
	printf '%s\n' "$fingerprint" > "$state_file" 2>/dev/null || true
fi

if $do_refresh; then
	set -- image-clean "$@"
fi

$DOCKER volume create "$build_vol" >/dev/null
$DOCKER volume create "$rootfs_vol" >/dev/null
$DOCKER volume create "$hosttools_vol" >/dev/null
$DOCKER volume create "$apt_vol" >/dev/null

tty=
if [ -t 0 ] && [ -t 1 ]; then
	tty="-it"
fi

# shellcheck disable=SC2086
exec $DOCKER run --privileged $tty --rm \
	-e TERM="${TERM:-xterm}" \
	-v "$REPO_DIR/configs":/configs \
	-v "$REPO_DIR/image":/output \
	-v "$build_vol":/build \
	-v "$rootfs_vol":/rootfs \
	-v "$hosttools_vol":/host-tools \
	-v "$apt_vol":/var/cache/apt \
	"$IMAGE" make "$@"
