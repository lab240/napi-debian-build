#!/bin/bash
# 06-cleanup.sh - размонтирование

log_info "Размонтирование..."

umount "${ROOTFS}/var/cache/apt/archives" 2>/dev/null || true
umount -l "${ROOTFS}/dev/pts"  2>/dev/null || true
umount -l "${ROOTFS}/dev"      2>/dev/null || true
umount -l "${ROOTFS}/sys"      2>/dev/null || true
umount -l "${ROOTFS}/proc"     2>/dev/null || true
umount    "${ROOTFS}"          || die "Не удалось размонтировать ${ROOTFS}"

losetup -d "${LOOP_DEV}" || die "Не удалось отключить ${LOOP_DEV}"
LOOP_DEV=""

rm -rf "${ROOTFS}"
ROOTFS=""

log_info "Размонтировано"
