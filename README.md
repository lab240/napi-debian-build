# Debian Build System for Napi-C, Napi-P, Napi-Slot (RK3308)

Debian image builder for boards based on the Rockchip RK3308 SoC (arm64):
- [Napi-C, Napi-P](https://github.com/napilab/napi-boards/blob/main/napic/README.md)
- [Napi-Slot](https://github.com/napilab/napi-boards/tree/main/napi-slot)

![alt text](img/napicp.png)

The build produces a bootable `.img.xz` disk image containing:
- U-Boot for RK3308
- Custom Linux 6.6 kernel with Rockchip patches
- Debian base system (trixie) with pre-installed packages

---

## Host Requirements

- Linux x86_64
- Must run as root (`sudo`)
- `debootstrap`, `qemu-user-static`, `binfmt-support`, `parted`, `xz-utils` — installed automatically on first run

---

## Pre-built Images

Ready-to-flash images are available at:
**<https://download.napilinux.ru/linuximg/napic/debian/>**

---

## Quick Start

```bash
git clone <url>
cd napi-debian-build
sudo ./mkimg.sh
```

The finished image will be placed in `artifacts-trixie/`.

---

## Build Options

```bash
sudo ./mkimg.sh [options]
```

| Option | Description |
|---|---|
| `--build-kernel` | Build kernel from source before creating the image |
| `--branch=rk-6.6` | Kernel branch (looks for `.deb` files in `kernel-<branch>/`) |
| `--skip-uboot` | Skip U-Boot flashing (rootfs only) |
| `--skip-xz` | Skip xz compression (faster, larger file) |

### Environment Variables

```bash
IMAGE_SIZE=2048       # Image size in MB (default: 2048)
DISTRIBUTION=trixie   # Debian release
HOSTNAME_TARGET=napic # Hostname set inside the image
EXTRA_PKGS=mc,htop    # Additional packages
KERNEL_VER=6.6.89     # Kernel version (auto-detected from .deb filename)
```

Example:

```bash
sudo IMAGE_SIZE=4096 EXTRA_PKGS=mc,htop ./mkimg.sh --skip-xz
```

---

## Repository Structure

```
config.sh              — all configuration and helper functions
mkimg.sh               — entry point, runs the build pipeline
packages.list          — packages to install into the image
napi-archive-keyring.asc — GPG key for deb.napilab.net

kernel-rk-6.6/        — pre-built kernel and headers .deb files
uboot/                 — pre-built U-Boot .deb for Napi-C

scripts/
  00-build-kernel.sh   — build kernel from source (only with --build-kernel)
  01-create-image.sh   — create .img, partition, format ext4
  02-debootstrap.sh    — install Debian base system into rootfs
  03-install-kernel.sh — install kernel, headers, DTB into rootfs
  04-boot-config.sh    — generate uEnv.txt, boot.cmd, boot.scr
  05-configure.sh      — system setup: packages, user, locale, SSH
  06-cleanup.sh        — unmount and clean up
  07-install-uboot.sh  — flash U-Boot into image, compress with xz
```

---

## APT Repositories in the Image

Two additional APT repositories are configured automatically:

**deb.napilab.net** — main Napi repository with the kernel and system packages.

**repo.napilab.ru** — repository with industrial protocol utilities:

| Package | Description |
|---|---|
| `mbusd` | Modbus RTU → TCP gateway |
| `mbscan` | Modbus device scanner |
| `modbus-slave` | Modbus slave emulator |

---

## Adding Packages to the Image

Edit `packages.list` — one package per line, comments with `#`:

```
# packages.list
mosquitto
mosquitto-clients
i2c-tools
```

---

## Building the Kernel from Source

To rebuild the kernel:

```bash
sudo ./mkimg.sh --build-kernel
```

The script will clone the kernel repository into `kernel-src/`, cross-compile `.deb` packages using `aarch64-linux-gnu-gcc`, and place them in `kernel-rk-6.6/`.

Kernel repository: `https://gitlab.nnz-ipc.net/pub/napilinux/kernel.git`, branch `rk-6.6`.

---

## First Boot on the Board

On first boot the image automatically expands the partition to fill the available storage and reboots.

SSH access:
- User: `napi` / password: `napilinux`
- User: `root` / password: `napilinux`
