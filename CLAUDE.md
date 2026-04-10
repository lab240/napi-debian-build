# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project does

Builds a Debian (trixie) disk image for the **Napi-C** board (RK3308 SoC, arm64). The output is a bootable `.img` (optionally `.img.xz`) with U-Boot, a custom Rockchip kernel, and a configured Debian rootfs.

## Running the build

Requires root on an x86_64 Linux host with `qemu-user-static` / `binfmt-support` (installed automatically if missing).

```bash
# Full build (kernel .deb must already exist in kernel-rk-6.6/)
sudo ./mkimg.sh

# Build kernel from source first, then image
sudo ./mkimg.sh --build-kernel

# Skip U-Boot flashing (image only)
sudo ./mkimg.sh --skip-uboot

# Skip xz compression
sudo ./mkimg.sh --skip-xz

# Override kernel branch (looks for .deb in kernel-<branch>/)
sudo ./mkimg.sh --branch=rk-6.6
```

Key environment variable overrides (can be set before calling mkimg.sh):
| Variable | Default | Meaning |
|---|---|---|
| `IMAGE_SIZE` | `2048` | Image size in MB |
| `DISTRIBUTION` | `trixie` | Debian release |
| `KERNEL_VER` | auto-detected | Kernel version string |
| `HOSTNAME_TARGET` | `napic` | Hostname set in image |
| `EXTRA_PKGS` | — | Extra packages added to both debootstrap and chroot install |
| `SKIP_UBOOT` | — | Set to any value to skip U-Boot |
| `SKIP_XZ` | — | Set to any value to skip compression |

Output lands in `artifacts-<DISTRIBUTION>/`.

## Architecture

All configuration lives in `config.sh`, which is sourced by `mkimg.sh` before any steps run. `mkimg.sh` then sources each `scripts/NN-*.sh` in numeric order via a loop — the scripts are **not executed as subprocesses**, they run in the same shell and share all variables.

### Build pipeline (scripts/ execution order)

| Script | What it does |
|---|---|
| `00-build-kernel.sh` | Skipped unless `--build-kernel`. Clones/updates kernel source, cross-compiles for arm64, copies resulting `.deb` files into `kernel-<branch>/`. |
| `01-create-image.sh` | Creates the raw `.img`, partitions it (msdos, one ext4 partition starting at sector 32768 to leave room for U-Boot), loop-mounts it, sets `ROOTFS` and `LOOP_DEV`. |
| `02-debootstrap.sh` | Runs `debootstrap --arch=arm64` into `ROOTFS`, sets fstab/hostname, bind-mounts `/proc /sys /dev /dev/pts` for chroot use. |
| `03-install-kernel.sh` | Copies kernel `.deb` (and optional headers `.deb`) into the rootfs and installs via `dpkg` in chroot. Copies DTBs and overlays to `/boot/dtbs/`. |
| `04-boot-config.sh` | Generates `/boot/uEnv.txt`, `/boot/boot.cmd`, compiles `/boot/boot.scr` with `mkimage`. Installs a kernel postinst hook (`zz-napi-update-boot`) that keeps these files in sync on future kernel upgrades. |
| `05-configure.sh` | Sets up APT repos (`deb.napilab.net` and `repo.napilab.ru`), installs `CHROOT_PKGS` + `packages.list` packages, creates `napi` user, sets locale (ru_RU.UTF-8), timezone (Europe/Moscow), enables SSH, creates MOTD, installs auto-resize-on-first-boot via `/etc/rc.local`. |
| `06-cleanup.sh` | Unmounts all chroot bind mounts, detaches loop device, removes temp `ROOTFS` dir. |
| `07-install-uboot.sh` | Extracts `u-boot-rockchip.bin` from the U-Boot `.deb` and `dd`s it at offset 32k into the raw image. Compresses and moves final image to `artifacts-<DISTRIBUTION>/`. |

### Key files and directories

- `config.sh` — single source of truth for all variables, helper functions (`log_info`, `die`, `check_root`, `cleanup`), and the `cleanup` trap.
- `kernel-rk-6.6/` — pre-built kernel `.deb` files; auto-detected by `config.sh`. The directory name encodes the kernel branch.
- `uboot/` — pre-built U-Boot `.deb` for Napi-C.
- `packages.list` — one package per line (comments with `#`) added to the chroot install. Edit this to add/remove packages from the image.
- `napi-archive-keyring.asc` — GPG key for `deb.napilab.net`, baked into the image.
- `cache/apt/` — bind-mounted into the rootfs during `05-configure.sh` to cache downloaded packages across builds (created automatically).

### Boot flow (on the target board)

U-Boot → reads `boot.scr` (compiled U-Boot script) → imports `uEnv.txt` → loads kernel, initrd, DTB, applies device tree overlays → boots Debian. On first boot `rc.local` auto-expands the partition to fill available storage and reboots.
