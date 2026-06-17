#!/bin/bash
set -euo pipefail

resolve_kdir() {
    if [ -n "${KDIR:-}" ]; then
        echo "${KDIR}"
        return
    fi

    if [ -n "${KERNEL_VERSION:-}" ]; then
        echo "/usr/src/kernels/${KERNEL_VERSION}"
        return
    fi

    local latest
    latest="$(ls -d /usr/src/kernels/* 2>/dev/null | sort -V | tail -1 || true)"
    if [ -z "${latest}" ]; then
        echo "No kernel headers found under /usr/src/kernels." >&2
        echo "Rebuild the image with KERNEL_VERSION set to your target kernel." >&2
        exit 1
    fi
    echo "${latest}"
}

usage() {
    cat <<'EOF'
Usage: docker-build.sh <command> [make args...]

Commands:
  build   Compile the serialfc.ko module (default)
  clean   Remove generated build artifacts
  shell   Open an interactive shell with KDIR exported
  kdir    Print the resolved kernel headers path

Environment:
  KERNEL_VERSION  Target kernel version (e.g. 4.18.0-513.11.1.el8_8.x86_64)
  KDIR            Override kernel headers path directly
  DEBUG=1         Passed through to make for debug builds
EOF
}

cmd="${1:-build}"
shift || true

case "${cmd}" in
    build)
        kdir="$(resolve_kdir)"
        if [ ! -d "${kdir}" ]; then
            echo "Kernel headers not found: ${kdir}" >&2
            exit 1
        fi
        echo "Building against KDIR=${kdir}"
        make -C "${kdir}" M="$(pwd)" modules "$@"
        ;;
    clean)
        make clean "$@"
        ;;
    shell)
        kdir="$(resolve_kdir)"
        export KDIR="${kdir}"
        echo "KDIR=${KDIR}"
        exec /bin/bash
        ;;
    kdir)
        resolve_kdir
        ;;
    help|-h|--help)
        usage
        ;;
    *)
        echo "Unknown command: ${cmd}" >&2
        usage >&2
        exit 1
        ;;
esac