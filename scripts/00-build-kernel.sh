#!/bin/bash
# 00-build-kernel.sh - сборка ядра из исходников (опционально)
if [[ -z "${BUILD_KERNEL}" ]]; then
    return 0
fi
log_info "Сборка ядра из исходников..."
KERNEL_SRC="${BASEDIR}/kernel-src"
KERNEL_JOBS="${KERNEL_JOBS:-$(nproc)}"
# Проверка кросс-компилятора
if ! command -v aarch64-linux-gnu-gcc &>/dev/null; then
    log_info "Установка кросс-компилятора..."
    apt-get install -y -qq gcc-aarch64-linux-gnu
fi
# Проверка qemu-user-static и libc6:arm64 (нужны для сборки host-скриптов под arm64)
if ! dpkg -l libc6:arm64 &>/dev/null 2>&1; then
    log_info "Установка libc6:arm64 и qemu-user-static..."
    dpkg --add-architecture arm64
    apt-get update -qq
    apt-get install -y -qq libc6:arm64 qemu-user-static
fi
# Клонирование или обновление
if [[ -d "${KERNEL_SRC}/.git" ]]; then
    log_info "Обновление исходников ядра..."
    cd "${KERNEL_SRC}"
    git fetch origin
    git checkout "${KERNEL_BRANCH}"
    git pull origin "${KERNEL_BRANCH}"
else
    log_info "Клонирование ${KERNEL_REPO} (${KERNEL_BRANCH})..."
    git clone -b "${KERNEL_BRANCH}" --depth 1 "${KERNEL_REPO}" "${KERNEL_SRC}"
    cd "${KERNEL_SRC}"
fi
# Сборка
log_info "Конфигурация: ${KERNEL_DEFCONFIG}"
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- "${KERNEL_DEFCONFIG}"
log_info "Сборка deb-пакетов (${KERNEL_JOBS} потоков)..."
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
    LOCALVERSION="${KERNEL_LOCALVERSION}" \
    KDEB_PKGVERSION="${KERNEL_VER}-napi1" \
    -j"${KERNEL_JOBS}" bindeb-pkg

# Пересборка host-скриптов под arm64
log_info "Пересборка host-скриптов под arm64..."
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- mrproper
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- HOSTCC=aarch64-linux-gnu-gcc "${KERNEL_DEFCONFIG}"
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- HOSTCC=aarch64-linux-gnu-gcc scripts scripts/mod/

cd "${BASEDIR}"
# Копируем собранные deb в kernel-<branch>/
mkdir -p "${KERNEL_DIR}"
BUILT_IMAGE=$(ls "${KERNEL_SRC}/../linux-image-"*.deb 2>/dev/null | head -1)
BUILT_HEADERS=$(ls "${KERNEL_SRC}/../linux-headers-"*.deb 2>/dev/null | head -1)
if [[ -f "${BUILT_IMAGE}" ]]; then
    cp "${BUILT_IMAGE}" "${KERNEL_DIR}/"
    KERNEL_DEB=$(basename "${BUILT_IMAGE}")
    KERNEL_VER=$(echo "${KERNEL_DEB}" | grep -oP 'linux-image-\K[0-9]+\.[0-9]+\.[0-9]+')
    log_info "Ядро собрано: ${KERNEL_DEB}"
else
    die "linux-image deb не найден после сборки"
fi
# Перепаковка headers deb с arm64 скриптами
if [[ -f "${BUILT_HEADERS}" ]]; then
    log_info "Перепаковка headers с arm64 скриптами..."
    HTMP=$(mktemp -d)
    dpkg-deb -R "${BUILT_HEADERS}" "${HTMP}"
    HSCRIPTS=$(find "${HTMP}" -path "*/usr/src/linux-headers-*/scripts" -type d | head -1)

    if [[ -n "${HSCRIPTS}" ]]; then
        HSRC=$(dirname "${HSCRIPTS}")
        cd "${KERNEL_SRC}"
        find "${HSCRIPTS}" -type f | while read f; do
            rel="${f#${HSRC}/}"
            if [[ -f "${rel}" ]] && file "$f" | grep -q "x86-64"; then
                if file "${rel}" | grep -q "aarch64"; then
                    cp "${rel}" "$f"
                fi
            fi
        done
        cd "${BASEDIR}"
    fi

    dpkg-deb -b "${HTMP}" "${BUILT_HEADERS}"
    rm -rf "${HTMP}"

    cp "${BUILT_HEADERS}" "${KERNEL_DIR}/"
    HEADERS_DEB=$(basename "${BUILT_HEADERS}")
    log_info "Headers собраны (arm64): ${HEADERS_DEB}"
fi
# Обновляем имя образа с актуальной версией ядра
IMAGE_NAME="Debian-napilab_${IMAGE_DATE}_${BOARD}_${DISTRIBUTION}_current_${KERNEL_VER}_${IMAGE_TYPE}"
IMAGE_FILE="${IMAGE_NAME}.img"
log_info "Сборка ядра завершена"
