#!/bin/bash
# 03-install-kernel.sh - установка ядра, headers и DTB

log_info "Установка ядра ${KERNEL_DEB} из ${KERNEL_DIR}/"
cp "${KERNEL_DIR}/${KERNEL_DEB}" "${ROOTFS}/tmp/"

KERNEL_FULL=$(dpkg-deb -f "${KERNEL_DIR}/${KERNEL_DEB}" Package | sed 's/linux-image-//')
if [[ -z "${KERNEL_FULL}" || "${KERNEL_FULL}" == "linux-image-" ]]; then
    KERNEL_FULL=$(dpkg-deb -c "${KERNEL_DIR}/${KERNEL_DEB}" | grep -oP 'boot/vmlinuz-\K\S+' | head -1)
fi
log_info "Полная версия ядра: ${KERNEL_FULL}"

chroot "${ROOTFS}" /bin/bash -e <<CHROOT_EOF
dpkg -i /tmp/$(basename "${KERNEL_DEB}")
rm -f /tmp/$(basename "${KERNEL_DEB}")
CHROOT_EOF

# Headers (install via apt install)
if [[ -n "${HEADERS_DEB}" && -f "${KERNEL_DIR}/${HEADERS_DEB}" ]]; then
    cp "${KERNEL_DIR}/${HEADERS_DEB}" "${ROOTFS}/tmp/"
    chroot "${ROOTFS}" /bin/bash -e <<CHROOT_EOF
dpkg -i /tmp/$(basename "${HEADERS_DEB}")
rm -f /tmp/$(basename "${HEADERS_DEB}")
CHROOT_EOF
    log_info "Headers установлены"
fi

KERNEL_DTB_SRC="${ROOTFS}/usr/lib/linux-image-${KERNEL_FULL}/rockchip"
BOOT_DTB_DST="${ROOTFS}/boot/dtbs"

mkdir -p "${BOOT_DTB_DST}"

if [[ -d "${KERNEL_DTB_SRC}" ]]; then
    cp "${KERNEL_DTB_SRC}"/*.dtb "${BOOT_DTB_DST}/"
    log_info "DTB скопированы: $(ls "${BOOT_DTB_DST}"/*.dtb | wc -l) файлов"

    if [[ -d "${KERNEL_DTB_SRC}/overlay" ]]; then
        cp -r "${KERNEL_DTB_SRC}/overlay" "${BOOT_DTB_DST}/"
        log_info "Overlays скопированы"
    fi
else
    die "DTB source не найден: ${KERNEL_DTB_SRC}"
fi

cd "${ROOTFS}/boot"
ln -sf "vmlinuz-${KERNEL_FULL}" vmlinuz
ln -sf "initrd.img-${KERNEL_FULL}" initrd.img
cd "${BASEDIR}"

log_info "Ядро установлено"
