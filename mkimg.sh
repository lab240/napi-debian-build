#!/bin/bash
# mkimg.sh - сборка образа Napi-C Debian

set -euo pipefail

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Предварительный разбор аргументов (до source config.sh) ---
for arg in "$@"; do
    case "${arg}" in
        --branch=*)    export KERNEL_BRANCH="${arg#*=}" ;;
    esac
done

source "${BASEDIR}/config.sh"

for arg in "$@"; do
    case "${arg}" in
        --skip-uboot)    SKIP_UBOOT=1 ;;
        --skip-xz)       SKIP_XZ=1 ;;
        --build-kernel)  BUILD_KERNEL=1 ;;
        --branch=*)      ;; # уже обработано выше
        --help|-h)
            echo "Usage: sudo $0 [options]"
            echo ""
            echo "Options:"
            echo "  --build-kernel      build kernel from source"
            echo "  --branch=rk-6.6     kernel branch (directory kernel-<branch>)"
            echo "  --skip-uboot        skip U-Boot installation"
            echo "  --skip-xz           skip xz compression"
            echo ""
            echo "Environment variables:"
            echo "  KERNEL_VER=6.6.89     kernel version"
            echo "  IMAGE_SIZE=2048       image size in MB"
            echo "  DISTRIBUTION=trixie   debian release"
            echo "  EXTRA_PKGS=pkg1,pkg2  additional packages"
            echo "  HOSTNAME_TARGET=napic target hostname"
            exit 0
            ;;
    esac
done

check_root
IMAGE_FILE="${IMAGE_NAME}.img"

log_info "Образ: ${IMAGE_NAME}"
log_info "Ядро: ${KERNEL_DIR}/${KERNEL_DEB}"
[[ -n "${HEADERS_DEB}" ]] && log_info "Headers: ${KERNEL_DIR}/${HEADERS_DEB}"

# --- Проверка зависимостей ---
log_info "Проверка зависимостей хоста..."
apt-get update -qq || true
apt-get install -y -qq u-boot-tools parted fdisk udev e2fsprogs dosfstools \
    debootstrap xz-utils qemu-user-static binfmt-support >/dev/null
log_info "Зависимости установлены"

# --- Проверка входных файлов ---
[[ -z "${BUILD_KERNEL}" ]] && check_file "${KERNEL_DIR}/${KERNEL_DEB}"
[[ -z "${SKIP_UBOOT}" ]] && check_file "${BASEDIR}/${UBOOT_DEB}"
check_file "${NAPI_KEY}"

# --- Trap для cleanup ---
trap cleanup EXIT

# --- Запуск шагов ---
for step in "${SCRIPTS}"/[0-9][0-9]-*.sh; do
    log_info "========== $(basename "${step}") =========="
    source "${step}"
done

# --- Отключаем trap ---
trap - EXIT

log_info "========== Готово! =========="
if [[ -z "${SKIP_XZ}" ]]; then
    log_info "Образ: ${BASEDIR}/artifacts-${DISTRIBUTION}/${IMAGE_FILE}.xz"
else
    log_info "Образ: ${BASEDIR}/artifacts-${DISTRIBUTION}/${IMAGE_FILE}"
fi
