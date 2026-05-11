#!/bin/bash
# 07-install-uboot.sh - прошивка U-Boot и упаковка
if [[ -z "${SKIP_UBOOT}" ]]; then
    log_info "Установка U-Boot (vendor chain)..."
    UBOOT_TMP=$(mktemp -d)
    dpkg-deb -x "${UBOOT_DIR}/${UBOOT_DEB}" "${UBOOT_TMP}"
    UBOOT_PATH="${UBOOT_TMP}/usr/lib/linux-u-boot-current-napic"
    LOOP_IMG=$(losetup --show -f "${IMAGE_FILE}")
    dd if="${UBOOT_PATH}/idbloader.bin" of="${LOOP_IMG}" seek=64    bs=512 conv=notrunc,fsync 2>/dev/null
    dd if="${UBOOT_PATH}/uboot.img"     of="${LOOP_IMG}" seek=16384 bs=512 conv=notrunc,fsync 2>/dev/null
    dd if="${UBOOT_PATH}/trust.bin"     of="${LOOP_IMG}" seek=24576 bs=512 conv=notrunc,fsync 2>/dev/null
    losetup -d "${LOOP_IMG}"
    rm -rf "${UBOOT_TMP}"
    log_info "U-Boot установлен (idbloader@64 uboot@16384 trust@24576)"
else
    log_info "U-Boot пропущен (--skip-uboot)"
fi
mkdir -p "${BASEDIR}/artifacts-${DISTRIBUTION}"
if [[ -z "${SKIP_XZ}" ]]; then
    log_info "Упаковка xz..."
    xz -zfvT0 "${IMAGE_FILE}"
    mv "${IMAGE_FILE}.xz" "${BASEDIR}/artifacts-${DISTRIBUTION}/"
    log_info "Образ упакован"
else
    mv "${IMAGE_FILE}" "${BASEDIR}/artifacts-${DISTRIBUTION}/"
    log_info "Образ сохранён без сжатия"
fi
