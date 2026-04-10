#!/bin/bash
# 02-debootstrap.sh - установка базовой системы Debian

PKGS="${BASE_PKGS}"
[[ -n "${EXTRA_PKGS}" ]] && PKGS="${PKGS},${EXTRA_PKGS}"

mkdir -p "${APT_CACHE}"

log_info "Debootstrap ${DISTRIBUTION} arm64..."
debootstrap --arch=arm64 --include="${PKGS}" --cache-dir="${APT_CACHE}" "${DISTRIBUTION}" "${ROOTFS}"
log_info "Debootstrap завершён"

echo "UUID=${ROOT_UUID}  /  ext4  defaults  0  0" > "${ROOTFS}/etc/fstab"
echo "${HOSTNAME_TARGET}" > "${ROOTFS}/etc/hostname"

mount -t proc     chproc  "${ROOTFS}/proc"
mount -t sysfs    chsys   "${ROOTFS}/sys"
mount -t devtmpfs chdev   "${ROOTFS}/dev"
mount -t devpts   chpts   "${ROOTFS}/dev/pts"
log_info "chroot mounts готовы"
