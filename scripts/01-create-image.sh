#!/bin/bash
# 01-create-image.sh - создание образа диска и разметка

log_info "Создание образа ${IMAGE_FILE} (${IMAGE_SIZE} MB)..."
dd bs=1M count=0 seek="${IMAGE_SIZE}" if=/dev/zero of="${IMAGE_FILE}" 2>/dev/null

log_info "Разметка: msdos, один Linux раздел с сектора ${START_SECTOR}..."
parted -s "${IMAGE_FILE}" mklabel msdos
echo "${START_SECTOR},,L" | sfdisk -q "${IMAGE_FILE}"

OFFSET=$((512 * START_SECTOR))
LOOP_DEV=$(losetup --offset "${OFFSET}" --show -f "${IMAGE_FILE}")
log_info "Loop device: ${LOOP_DEV}"

log_info "Форматирование ext4..."
mkfs.ext4 -F -q -L "${HOSTNAME_TARGET}" "${LOOP_DEV}"

ROOTFS=$(mktemp -d)
mount "${LOOP_DEV}" "${ROOTFS}"
ROOT_UUID=$(blkid -s UUID -o value "${LOOP_DEV}")
log_info "Примонтировано: ${ROOTFS} (UUID=${ROOT_UUID})"
