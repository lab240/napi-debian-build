#!/bin/bash
# 04-boot-config.sh - генерация boot.cmd, uEnv.txt, boot.scr

INITRD_SIZE=$(printf "0x%X" "$(stat --format=%s "${ROOTFS}/boot/initrd.img-${KERNEL_FULL}")")

cat > "${ROOTFS}/boot/uEnv.txt" <<EOF
# /boot/uEnv.txt - настройки загрузки Napi-C
fdtfile=${FDT_FILE}
console=ttyS0,1500000n8
verbosity=7
overlays=rk3308-uart0 rk3308-uart1 rk3308-uart2-m0 rk3308-uart3-m0 rk3308-i2c1-ds1338 rk3308-i2c3-m0 rk3308-usb20-host
rootuuid=${ROOT_UUID}
initrdsize=${INITRD_SIZE}
initrdimg=boot/initrd.img-${KERNEL_FULL}
kernelimg=boot/vmlinuz-${KERNEL_FULL}
EOF
log_info "uEnv.txt создан"

cat > "${ROOTFS}/boot/boot.cmd" <<'BOOTCMD'
setenv load_addr "0x05000000"
setenv overlay_error "false"
setenv rootfstype "ext4"

echo "Boot script loaded from ${devtype} ${devnum}"

if test -e ${devtype} ${devnum} boot/uEnv.txt; then
    load ${devtype} ${devnum} ${load_addr} boot/uEnv.txt
    env import -t ${load_addr} ${filesize}
fi

setenv bootargs "root=UUID=${rootuuid} rootwait rw rootfstype=${rootfstype} console=tty1 console=${console} loglevel=${verbosity} ${extraargs}"

load ${devtype} ${devnum} ${ramdisk_addr_r} ${initrdimg}
load ${devtype} ${devnum} ${kernel_addr_r} ${kernelimg}

load ${devtype} ${devnum} ${fdt_addr_r} boot/dtbs/${fdtfile}.dtb
fdt addr ${fdt_addr_r}
fdt resize 65536

for overlay_file in ${overlays}; do
    if load ${devtype} ${devnum} ${load_addr} boot/dtbs/overlay/rk3308/${overlay_file}.dtbo; then
        echo "Applying overlay: ${overlay_file}"
        fdt apply ${load_addr} || setenv overlay_error "true"
    fi
done

if test "${overlay_error}" = "true"; then
    echo "Error applying overlays, reloading original DTB"
    load ${devtype} ${devnum} ${fdt_addr_r} boot/dtbs/${fdtfile}.dtb
fi

echo "initrdsize = ${initrdsize}"
booti ${kernel_addr_r} ${ramdisk_addr_r}:${initrdsize} ${fdt_addr_r}
BOOTCMD
log_info "boot.cmd создан"

mkimage -C none -A arm64 -T script -d "${ROOTFS}/boot/boot.cmd" "${ROOTFS}/boot/boot.scr" >/dev/null
log_info "boot.scr скомпилирован"

mkdir -p "${ROOTFS}/etc/kernel/postinst.d"
cat > "${ROOTFS}/etc/kernel/postinst.d/zz-napi-update-boot" <<'HOOK'
#!/bin/bash
VERSION="$1"
KERNEL_DTB_SRC="/usr/lib/linux-image-${VERSION}/rockchip"
BOOT_DTB_DST="/boot/dtbs"

if [[ -d "${KERNEL_DTB_SRC}" ]]; then
    cp "${KERNEL_DTB_SRC}"/*.dtb "${BOOT_DTB_DST}/"
fi

if [[ -d "${KERNEL_DTB_SRC}/overlay" ]]; then
    cp -r "${KERNEL_DTB_SRC}/overlay" "${BOOT_DTB_DST}/"
fi

ln -sf "/boot/vmlinuz-${VERSION}" /boot/vmlinuz
ln -sf "/boot/initrd.img-${VERSION}" /boot/initrd.img

INITRD_SIZE=$(printf "0x%X" "$(stat --format=%s "/boot/initrd.img-${VERSION}")")
sed -i "s|^initrdimg=.*|initrdimg=boot/initrd.img-${VERSION}|" /boot/uEnv.txt
sed -i "s|^initrdsize=.*|initrdsize=${INITRD_SIZE}|" /boot/uEnv.txt
sed -i "s|^kernelimg=.*|kernelimg=boot/vmlinuz-${VERSION}|" /boot/uEnv.txt

if [[ -f /boot/boot.cmd ]]; then
    mkimage -C none -A arm64 -T script -d /boot/boot.cmd /boot/boot.scr >/dev/null 2>&1
fi
HOOK
chmod +x "${ROOTFS}/etc/kernel/postinst.d/zz-napi-update-boot"
log_info "Kernel postinst hook установлен"
