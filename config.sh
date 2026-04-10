#!/bin/bash
# config.sh - конфигурация сборки образа Napi-C Debian

set -euo pipefail

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="${BASEDIR}/scripts"

# --- Пароль по умолчанию (napilinux) ---
DEFAULT_PASS_HASH='$6$T4DupqvBA1igpFDI$SbpgmAgBm0YDOcNyBtahOezoIOCj78HfmVdoOYJneWLe/R2Tni5g4qclDhRR5yrgcQDRIv/lX.RA73KrHpxrU0'

# --- Образ ---
IMAGE_SIZE="${IMAGE_SIZE:-2048}"
IMAGE_TYPE="${IMAGE_TYPE:-minimal}"
IMAGE_DATE=$(date +%d%b-%H%M)
IMAGE_FILE=""

# --- Разметка ---
START_SECTOR="${START_SECTOR:-32768}"

# --- Платформа ---
SOC="rk3308"
BOARD="napi-c"
FDT_FILE="rk3308-napi-c"
HOSTNAME_TARGET="${HOSTNAME_TARGET:-napic}"

# --- Ядро ---
KERNEL_VER="${KERNEL_VER:-6.6.89}"
KERNEL_BRANCH="${KERNEL_BRANCH:-rk-6.6}"
KERNEL_DIR="${BASEDIR}/kernel-${KERNEL_BRANCH}"
KERNEL_DEFCONFIG="${KERNEL_DEFCONFIG:-napi_defconfig}"
KERNEL_LOCALVERSION="${KERNEL_LOCALVERSION:--napi-c}"
KERNEL_REPO="${KERNEL_REPO:-https://gitlab.nnz-ipc.net/pub/napilinux/kernel.git}"

# Автоопределение deb из kernel-<бранч>/
if [[ "${KERNEL_DEB:-auto}" == "auto" ]]; then
    _found=$(ls "${KERNEL_DIR}"/linux-image-*.deb 2>/dev/null | head -1) || true
    if [[ -n "${_found}" ]]; then
        KERNEL_DEB=$(basename "${_found}")
        KERNEL_VER=$(echo "${KERNEL_DEB}" | grep -oP 'linux-image-\K[0-9]+\.[0-9]+\.[0-9]+')
    else
        KERNEL_DEB="linux-image-${KERNEL_VER}_${KERNEL_VER}-napi1_arm64.deb"
    fi
fi

if [[ "${HEADERS_DEB:-auto}" == "auto" ]]; then
    _found=$(ls "${KERNEL_DIR}"/linux-headers-*.deb 2>/dev/null | head -1) || true
    if [[ -n "${_found}" ]]; then
        HEADERS_DEB=$(basename "${_found}")
    else
        HEADERS_DEB=""
    fi
fi

# --- U-Boot ---
UBOOT_DEB="${UBOOT_DEB:-uboot/linux-u-boot-napic-current_07Apr-0113-rt_arm64__2024.10-Sf919-P872d-Hbed3-V3c06-Bbf55-R448a.deb}"

# --- Debian ---
DISTRIBUTION="${DISTRIBUTION:-trixie}"
EXTRA_PKGS="${EXTRA_PKGS:-}"
BASE_PKGS="gpg,ca-certificates,initramfs-tools,locales,nano,ssh,ntpsec,dosfstools,curl,zstd,wireless-regdb,sudo"
CHROOT_PKGS="network-manager"

# Дополнительные пакеты из файла packages.list
PACKAGES_LIST="${BASEDIR}/packages.list"
if [[ -f "${PACKAGES_LIST}" ]]; then
    while IFS= read -r pkg; do
        pkg="${pkg%%#*}"
        pkg="${pkg// /}"
        [[ -n "${pkg}" ]] && CHROOT_PKGS="${CHROOT_PKGS},${pkg}"
    done < "${PACKAGES_LIST}"
fi

# --- Napi APT repo ---
NAPI_REPO="https://deb.napilab.net"
NAPI_KEY="${BASEDIR}/napi-archive-keyring.asc"

# --- Кеш пакетов ---
APT_CACHE="${BASEDIR}/cache/apt"


# --- Имя образа ---
IMAGE_NAME="Debian-napilab_${IMAGE_DATE}_${BOARD}_${DISTRIBUTION}_current_${KERNEL_VER}_${IMAGE_TYPE}"

# --- Рабочие переменные ---
ROOTFS=""
LOOP_DEV=""
ROOT_UUID=""

# --- Флаги ---
SKIP_UBOOT="${SKIP_UBOOT:-}"
SKIP_XZ="${SKIP_XZ:-}"
BUILD_KERNEL="${BUILD_KERNEL:-}"

# --- Функции ---
log_info()  { echo -e "\e[32m[INFO]\e[0m $*"; }
log_warn()  { echo -e "\e[33m[WARN]\e[0m $*"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $*"; }

die() {
    log_error "$@"
    exit 1
}

check_root() {
    [[ "$(id -u)" -eq 0 ]] || die "Запусти от root: sudo $0"
}

check_file() {
    [[ -f "$1" ]] || die "Файл не найден: $1"
}

cleanup() {
    log_info "Cleanup..."
    umount "${ROOTFS}/var/cache/apt/archives" 2>/dev/null || true
    umount -l "${ROOTFS}"/{dev/pts,dev,sys,proc} 2>/dev/null || true
    umount -l "${ROOTFS}" 2>/dev/null || true
    [[ -n "${LOOP_DEV}" ]] && losetup -d "${LOOP_DEV}" 2>/dev/null || true
    [[ -n "${ROOTFS}" && "${ROOTFS}" == /tmp/* ]] && rm -rf "${ROOTFS}" 2>/dev/null || true
}
