#!/usr/bin/env bash
# Build linuwu_sense against the kernel that ships in this image and install it
# into /usr/lib/modules, so it is part of the (immutable) OS image.
#
# Upstream: https://github.com/0x7375646F/Linuwu-Sense
set -euo pipefail

readonly MODULE="linuwu_sense"
readonly REPO="https://github.com/0x7375646F/Linuwu-Sense.git"

# Version of the kernel the finished image will boot. There is normally exactly
# one kernel package; if there are several, take the newest.
KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel | sort -V | tail -n1)"
if [[ -z "${KVER}" ]]; then
    echo "ERROR: could not determine the kernel version" >&2
    exit 1
fi
echo "==> Building ${MODULE} for kernel ${KVER}"

# Remember which build-only packages are not already in the base image, so we
# can remove exactly those again afterwards (all in one layer, so they do not
# end up in the final image).
ADDED=()
for pkg in gcc make git dwarves "kernel-devel-${KVER}"; do
    rpm -q "${pkg}" >/dev/null 2>&1 || ADDED+=("${pkg}")
done

echo "==> Installing build dependencies"
dnf install -y --setopt=install_weak_deps=False gcc make git dwarves "kernel-devel-${KVER}"

if [[ ! -d "/lib/modules/${KVER}/build" ]]; then
    echo "ERROR: kernel headers for ${KVER} were not installed" >&2
    exit 1
fi

BUILDDIR="$(mktemp -d)"
trap 'rm -rf "${BUILDDIR}"' EXIT

echo "==> Fetching ${REPO}"
git clone --depth 1 "${REPO}" "${BUILDDIR}/Linuwu-Sense"
cd "${BUILDDIR}/Linuwu-Sense"

# Call the kernel build system directly instead of upstream's `all` target:
# that target also tries to sign the module with a local MOK key.
echo "==> Compiling"
make -C "/lib/modules/${KVER}/build" M="${PWD}" modules

echo "==> Installing"
install -Dm644 "src/${MODULE}.ko" "/usr/lib/modules/${KVER}/extra/${MODULE}.ko"
depmod -a "${KVER}"

# Enabled units live in files/system; enable them here so the symlinks are part
# of the image.
systemctl enable linuwu_sense.service linuwu-sense-permissions.service

echo "==> Removing build dependencies"
if ((${#ADDED[@]})); then
    dnf remove -y "${ADDED[@]}"
fi
dnf clean all

echo "==> ${MODULE} installed for ${KVER}"
