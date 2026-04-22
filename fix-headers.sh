#!/bin/bash
# fix-headers.sh - перепаковка linux-headers deb с arm64 скриптами
# Использование: sudo bash fix-headers.sh
set -e

BASEDIR="$(cd "$(dirname "$0")" && pwd)"
KERNEL_DIR="${BASEDIR}/kernel-rk-6.6"
KERNEL_SRC="${BASEDIR}/kernel-src"

# Находим headers deb
HEADERS_DEB=$(ls "${KERNEL_DIR}"/linux-headers-*.deb 2>/dev/null | head -1)
if [[ -z "${HEADERS_DEB}" ]]; then
    echo "ОШИБКА: linux-headers deb не найден в ${KERNEL_DIR}/"
    exit 1
fi
echo "Headers deb: ${HEADERS_DEB}"

# Проверяем наличие исходников с arm64 скриптами
if [[ ! -f "${KERNEL_SRC}/scripts/basic/fixdep" ]]; then
    echo "ОШИБКА: скрипты ядра не собраны. Сначала выполни:"
    echo "  cd ${KERNEL_SRC}"
    echo "  make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- HOSTCC=aarch64-linux-gnu-gcc mrproper"
    echo "  make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- HOSTCC=aarch64-linux-gnu-gcc napi_defconfig"
    echo "  make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- HOSTCC=aarch64-linux-gnu-gcc scripts"
    exit 1
fi

# Проверяем что скрипты действительно arm64
if ! file "${KERNEL_SRC}/scripts/basic/fixdep" | grep -q "aarch64"; then
    echo "ОШИБКА: scripts/basic/fixdep не arm64. Пересобери скрипты с HOSTCC=aarch64-linux-gnu-gcc"
    exit 1
fi

# Распаковываем headers deb
HTMP=$(mktemp -d)
echo "Распаковка ${HEADERS_DEB}..."
dpkg-deb -R "${HEADERS_DEB}" "${HTMP}"

# Ищем scripts/ в usr/src/linux-headers-*
HSCRIPTS=$(find "${HTMP}" -path "*/usr/src/linux-headers-*/scripts" -type d | head -1)
if [[ -z "${HSCRIPTS}" ]]; then
    echo "ОШИБКА: не найден scripts/ внутри headers deb"
    rm -rf "${HTMP}"
    exit 1
fi

HSRC=$(dirname "${HSCRIPTS}")
echo "Headers src dir: ${HSRC}"

# Заменяем x86 бинарники на arm64
cd "${KERNEL_SRC}"
find "${HSCRIPTS}" -type f | while read f; do
    rel="${f#${HSRC}/}"
    if [[ -f "${rel}" ]] && file "$f" | grep -q "x86-64"; then
        if file "${rel}" | grep -q "aarch64"; then
            echo "  Replacing: ${rel}"
            cp "${rel}" "$f"
        fi
    fi
done
cd "${BASEDIR}"

# Перепаковываем
echo "Перепаковка deb..."
dpkg-deb -b "${HTMP}" "${HEADERS_DEB}"
rm -rf "${HTMP}"

echo ""
echo "Готово: ${HEADERS_DEB}"
echo ""
echo "Проверка:"
HTMP2=$(mktemp -d)
dpkg-deb -R "${HEADERS_DEB}" "${HTMP2}"
HSCRIPTS2=$(find "${HTMP2}" -path "*/usr/src/linux-headers-*/scripts" -type d | head -1)
file "${HSCRIPTS2}/basic/fixdep"
file "${HSCRIPTS2}/kconfig/conf"
rm -rf "${HTMP2}"
