# Muthur Command Operating System

Muthur Command Operating System (MCOS) is a Linux based operating system
optimized to host Muthur Command services and managed apps.

MCOS uses Docker as its container engine. By default it deploys the MCOS containers stack
Supervisor as a container. MCOS Supervisor then controls MC stack services in
separate containers. MCOS is **not** based on a regular Linux distribution like
Ubuntu. It is built using [Buildroot](https://buildroot.org/) and targets SBC
devices like Raspberry Pi/ODROID as well as x86-64 systems with UEFI.

[![Muthur Command](https://img.shields.io/badge/OS-MCOS-blue)](https://github.com/muthur-command/operating-system)

## Features

- Lightweight and memory-efficient
- Minimized I/O
- Over The Air (OTA) updates
- Offline updates
- Modular using Docker container engine

## Supported hardware

The list of supported hardware is maintained in this repository's board
metadata and migration planning documents.

## Getting Started

If you just want to use MCOS, follow your project's installation and release
notes for the latest images and OTA channels.

On the host OS, the CLI is installed as `mc` (primary) or `mcos-cli` (interactive session),
both wrappers that reach the Supervisor CLI container.

## Development

If you don't have experience with embedded systems, Buildroot or the build process for Linux distributions it is recommended to read up on these topics first (e.g. [Bootlin](https://bootlin.com/docs/) has excellent resources).

Project-specific MCOS documentation is maintained in the mc_os note repository.

### Components

- **Bootloader:**
  - [GRUB](https://www.gnu.org/software/grub/) for devices that support UEFI
  - [U-Boot](https://www.denx.de/wiki/U-Boot) for devices that don't support UEFI
- **Operating System:**
  - [Buildroot](https://buildroot.org/) LTS Linux
- **File Systems:**
  - [SquashFS](https://www.kernel.org/doc/Documentation/filesystems/squashfs.txt) for read-only file systems (using LZ4 compression)
  - [ZRAM](https://www.kernel.org/doc/Documentation/blockdev/zram.txt) for `/tmp`, `/var` and swap (using LZ4 compression)
- **Container Platform:**
  - [Docker Engine](https://docs.docker.com/engine/) for running MC components in containers
- **Updates:**
  - [RAUC](https://rauc.io/) for Over The Air (OTA) and USB updates
- **Security:**
  - [AppArmor](https://apparmor.net/) Linux kernel security module

### Development builds

The Development build GitHub Action Workflow is a manually triggered workflow
which creates MCOS development builds. Development builds are published to the
configured MCOS artifacts endpoint for the repository environment.
