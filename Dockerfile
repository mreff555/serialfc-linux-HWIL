# Build serialfc-linux kernel module on CentOS 8 (from macOS or any host via Docker).
#
# This is a two-step process:
#
#   Step 1 — Build the image (installs gcc, make, kernel headers; does NOT compile):
#     docker build -t serialfc-build .
#
#   Step 2 — Compile the module (run from the repo root, where Makefile lives):
#     docker run --rm -v "$(pwd):/src" serialfc-build
#
#   Output: serialfc.ko is written to the repo root on your host (same directory
#   as Makefile). It is gitignored (*.ko) but should appear on disk:
#     ls -la serialfc.ko
#
# The built .ko must be loaded on a machine running the same kernel version as the
# installed kernel-devel headers. Override KERNEL_VERSION to match your target host:
#
#   docker build --build-arg KERNEL_VERSION=4.18.0-513.11.1.el8_8.x86_64 -t serialfc-build .
#   docker run --rm -v "$(pwd):/src" serialfc-build
#
# Other useful commands:
#   docker run --rm -v "$(pwd):/src" -e DEBUG=1 serialfc-build   # debug build
#   docker run --rm -v "$(pwd):/src" serialfc-build clean        # remove artifacts
#   docker run --rm serialfc-build dnf list --showduplicates kernel-devel

FROM quay.io/centos/centos:8

ARG KERNEL_VERSION=

# CentOS 8 reached EOL; use vault mirrors.
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-* \
    && sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*

RUN dnf -y install gcc make elfutils-libelf-devel \
    && if [ -n "${KERNEL_VERSION}" ]; then \
         dnf -y install "kernel-devel-${KERNEL_VERSION}"; \
       else \
         dnf -y install kernel-devel; \
       fi \
    && dnf clean all

WORKDIR /src

COPY docker-build.sh /usr/local/bin/docker-build.sh
RUN chmod +x /usr/local/bin/docker-build.sh

ENTRYPOINT ["/usr/local/bin/docker-build.sh"]
CMD ["build"]