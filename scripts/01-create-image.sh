#!/bin/bash
# 01-create-image.sh - создание образа диска и разметка
log_info "Создание образа ${IMAGE_FILE} (${IMAGE_SIZE} MB)..."
dd bs=1M count=0 seek="${IMAGE_SIZE}" if=/dev/zero of="${IMAGE_FILE}" 2>/dev/null
log_info "Разметка: GPT, один Linux раздел с сектора ${START_SECTOR}..."

END_SECTOR=$(( (IMAGE_SIZE * 1024 * 1024 / 512) - 34 ))
PART_SECTORS=$(( END_SECTOR - START_SECTOR + 1 ))
sgdisk -o \
    -n 1:${START_SECTOR}:${END_SECTOR} \
    -t 1:8300 \
    -c 1:"rootfs" \
    "${IMAGE_FILE}"
OFFSET=$((512 * START_SECTOR))
LOOP_DEV=$(losetup --offset "${OFFSET}" --sizelimit $((PART_SECTORS * 512)) --show -f "${IMAGE_FILE}")

log_info "Loop device: ${LOOP_DEV}"
log_info "Форматирование ext4..."
mkfs.ext4 -F -q -L "${HOSTNAME_TARGET}" "${LOOP_DEV}"
ROOTFS=$(mktemp -d)
mount "${LOOP_DEV}" "${ROOTFS}"
ROOT_UUID=$(blkid -s UUID -o value "${LOOP_DEV}")
log_info "Примонтировано: ${ROOTFS} (UUID=${ROOT_UUID})"
