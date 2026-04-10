#!/bin/bash
# 05-configure.sh - настройка системы в chroot

KEYRINGS_PATH="/usr/share/keyrings"
KEY_NAME="napi-archive-keyring"

# --- deb.napilab.net ---
cat > "${ROOTFS}/etc/apt/sources.list.d/napi.sources" <<EOF
Types: deb deb-src
URIs: ${NAPI_REPO}
Suites: ${DISTRIBUTION}
Components: main
Signed-By: ${KEYRINGS_PATH}/${KEY_NAME}.gpg
EOF

gpg --dearmor < "${NAPI_KEY}" > "${ROOTFS}/${KEYRINGS_PATH}/${KEY_NAME}.gpg"
log_info "deb.napilab.net настроен"

# --- repo.napilab.ru ---
chroot "${ROOTFS}" /bin/bash -e <<'CHROOT_EOF'
curl -fsSL https://repo.napilab.ru/napilab.gpg | gpg --dearmor > /usr/share/keyrings/napilab.gpg
echo "deb [signed-by=/usr/share/keyrings/napilab.gpg] https://repo.napilab.ru stable main" > /etc/apt/sources.list.d/napilab.list
CHROOT_EOF
log_info "repo.napilab.ru настроен"

# --- Монтируем кеш пакетов ---
mkdir -p "${APT_CACHE}" "${ROOTFS}/var/cache/apt/archives"
mount --bind "${APT_CACHE}" "${ROOTFS}/var/cache/apt/archives"

# --- Дополнительные пакеты в chroot ---
INSTALL_PKGS="${CHROOT_PKGS}"
[[ -n "${EXTRA_PKGS}" ]] && INSTALL_PKGS="${INSTALL_PKGS},${EXTRA_PKGS}"

chroot "${ROOTFS}" /bin/bash -e <<EOF
apt-get update -qq
apt-get install -y ${INSTALL_PKGS//,/ }
EOF
log_info "Дополнительные пакеты установлены"

# --- Пользователи ---
chroot "${ROOTFS}" /bin/bash -e <<CHROOT_EOF
useradd -m -s /bin/bash -G sudo -p '${DEFAULT_PASS_HASH}' napi
usermod -p '${DEFAULT_PASS_HASH}' root
CHROOT_EOF

# --- Настройка в chroot ---
chroot "${ROOTFS}" /bin/bash -e <<'CHROOT_EOF'
# Locale
if [[ -f /etc/default/console-setup ]]; then
    sed -i -e 's/CHARMAP=.*/CHARMAP="UTF-8"/' -e 's/CODESET=.*/CODESET="CyrSlav"/' /etc/default/console-setup
else
    echo -e 'CHARMAP="UTF-8"\nCODESET="CyrSlav"' > /etc/default/console-setup
fi
echo 'LANG="ru_RU.UTF-8"' >> /etc/environment
sed -i 's/^#\s*\(ru_RU\.UTF-8\|en_US\.UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo "LANG=ru_RU.UTF-8" > /etc/locale.conf

# Timezone
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime

# SSH
systemctl enable ssh.service
CHROOT_EOF
log_info "Система настроена"

# --- MOTD ---
cat > "${ROOTFS}/etc/motd" <<'MOTD'

  _   _             _ ____       _     _
 | \ | | __ _ _ __ (_)  _ \  ___| |__ (_) __ _ _ __
 |  \| |/ _` | '_ \| | | | |/ _ \ '_ \| |/ _` | '_ \
 | |\  | (_| | |_) | | |_| |  __/ |_) | | (_| | | | |
 |_| \_|\__,_| .__/|_|____/ \___|_.__/|_|\__,_|_| |_|
              |_|
  Based on Debian GNU/Linux | Kernel 6.6 | RK3308

MOTD
log_info "MOTD создан"

# --- Скрипт показа IP при логине ---
cat > "${ROOTFS}/etc/profile.d/napi-ip.sh" <<'IPSCRIPT'
_ips=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -v '^$' | head -3)
if [ -n "$_ips" ]; then
    echo "  IP: $(echo $_ips | tr '\n' ' ')"
    echo ""
fi
unset _ips
IPSCRIPT
chmod +x "${ROOTFS}/etc/profile.d/napi-ip.sh"
log_info "IP в motd настроен"

# --- Размонтируем кеш пакетов ---
umount "${ROOTFS}/var/cache/apt/archives"

# --- Auto-resize при первом запуске ---
cat > "${ROOTFS}/etc/rc.local" <<'RCLOCAL'
#!/bin/bash
eval $(lsblk -P -o MOUNTPOINTS,PARTN,PKNAME | grep 'MOUNTPOINTS="/"')
echo ", +" | sfdisk -f -N "${PARTN}" "/dev/${PKNAME}"
resize2fs "/dev/${PKNAME}${PARTN}" 2>/dev/null || true
(sleep 0.1; rm -f /etc/rc.local; reboot) &
RCLOCAL
chmod +x "${ROOTFS}/etc/rc.local"
log_info "Auto-resize настроен"
