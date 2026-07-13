# Neardi LB200 (RK3576) 启动链说明

本文档说明 MCOS 在 Neardi LB200 板上的启动流程，以及启动日志中为何同时出现
**U-Boot SPL 2017.09** 与 **U-Boot 2026.04** 两个版本。

适用镜像：`mc_neardi_lb200` defconfig 构建产物。  
相关源码路径：`buildroot-external/board/neardi/lb200/`。

## 概述

LB200 采用 **Rockchip 混合启动链**：最前端几段固件来自供应商 rkbin，中段为
ARM Trusted Firmware / OP-TEE，**主 U-Boot 与 Linux 内核由 MCOS Buildroot 构建**
（mainline U-Boot 2026 + Linux 6.18）。

启动日志里看到 `U-Boot SPL 2017.09` **是预期行为**，不代表刷错了固件。

## 完整启动链

上电后各阶段与串口日志中的标识对应关系如下：

| 顺序 | 阶段 | 日志中的典型标识 | 来源 | 职责 |
|------|------|------------------|------|------|
| 1 | DDR 训练 | `DDR a6303af65c ... fwver: v1.06` | rkbin DDR blob | 初始化 LPDDR4X |
| 2 | USB 下载模式（可选） | `USB-PLUG 2017.09-...` | rkbin | USB 烧录 / 恢复 |
| 3 | SPL（第一阶段引导） | `U-Boot SPL 2017.09-...` | rkbin MiniLoader/SPL | 从 `uboot` 分区加载 FIT |
| 4 | 安全固件 | `BL31` / `OP-TEE` | ATF + tee.bin | EL3 运行时、TEE |
| 5 | U-Boot 主程序（BL33） | `U-Boot 2026.04` | mainline 构建 | 读 eMMC、加载内核、传 bootargs |
| 6 | Linux 内核 | `Linux 6.18.x-mcos` | mainline 构建 | 从 `boot_a` / `boot_b` 启动 |

用流程图表示：

```
SoC ROM
  → rkbin DDR blob
  → [可选] USB-PLUG 2017.09
  → U-Boot SPL 2017.09（供应商）
       → 从 uboot 分区读取 u-boot.itb（FIT）
       → 校验 ATF / U-Boot / OP-TEE / FDT
  → BL31 + OP-TEE
  → U-Boot 2026.04（mainline BL33）
       → 从 boot_a / boot_b 读取内核 FIT
       → bootm 启动 Linux
  → Linux 6.18
```

## 为何日志里是 U-Boot 2017.09，而不是全程 2026？

### U-Boot SPL 2017.09 是什么？

它是 **Rockchip 官方 rkbin 包里的 SPL（Secondary Program Loader）**，不是从
mainline U-Boot 源码编出来的：

- 版本字符串 `2017.09` 来自 Rockchip 基于旧版 U-Boot 的长期维护分支，标识一直沿用
- 构建时由 `board/neardi/lb200/scripts/mk-loader.sh` 调用 `boot_merger` 与
  `RK3576MINIALL.ini`，生成 `MiniLoaderAll.bin`
- 该镜像写在 eMMC 最前端；SoC 上电后 ROM **只认** 这套供应商 loader

SPL 在日志中的典型工作（摘自 `logs/mcos_startup.log`）：

```
U-Boot SPL 2017.09-g8532be3569c-240909 #lxh (Sep 13 2024 - 11:28:35), fwver: v1.06
Trying to boot from MMC1
SPL: A/B-slot: _a, successful: 0, tries-remain: 7
Trying fit image at 0x4000 sector
## Checking u-boot 0x40800000 ... OK
Jumping to U-Boot(0x40800000) via ARM Trusted Firmware(0x40060000)
```

含义：从 GPT `uboot` 分区（LBA `0x4000`）读取 FIT，校验通过后把 **mainline
U-Boot 2026.04** 交给 ATF，再跳入 BL33。

### U-Boot 2026.04 是什么？

这是 **MCOS 用 mainline U-Boot 源码构建的 BL33（U-Boot proper）**，配置覆盖见
`board/neardi/lb200/uboot.config`，板级补丁见 `board/neardi/lb200/patches/uboot/`。

日志中在其后出现，例如：

```
U-Boot 2026.04 (Jul 03 2026 - 08:56:08 +0000)
...
## Loading kernel (any) from FIT Image at 4a000000 ...
Starting kernel ...
```

职责：初始化 eMMC（在 SPL 已拉起的前提下）、读取 `boot_a` / `boot_b` 分区中的
内核 FIT、设置 `bootargs`、执行 `bootm` 进入 Linux。

### 为何采用混合方案，不用全程 mainline U-Boot？

`uboot.config` 中已注明设计意图：

> Vendor rkbin SPL (U-Boot 2017.09) loads an unsigned FIT from uboot

主要原因：

1. **SoC ROM 固定加载 rkbin MiniLoader**  
   RK3576 上电路径由硬件与 Rockchip 闭源 blob 决定，无法用 mainline SPL 直接替换最前端。

2. **供应商 SPL 完成了大量板级初始化**  
   包括 DDR、eMMC、部分电源与引脚配置。mainline SPL 对 RK3576 仍不完整；BL33 侧
   大量补丁（跳过 `lowlevel_init`、避免重复初始化 SDHCI/UART 等）的前提是 **SPL
   已完成这些工作**。

3. **MCOS 实际维护的是 BL33 及之后**  
   `board/neardi/lb200/scripts/mk-uboot-img.sh` 将 mainline 构建的 `u-boot.itb`
   写入 `uboot` 分区；日常改启动参数、分区读取、内核加载逻辑，改的是 **U-Boot
   2026**，而非 rkbin SPL。

可概括为：

| 组件 | 版本 | 是否由 MCOS 构建 | 是否建议替换 |
|------|------|------------------|--------------|
| MiniLoader / SPL | U-Boot 2017.09（rkbin） | 否 | 否（除非退回全 SDK 方案） |
| U-Boot proper（BL33） | U-Boot 2026.04（mainline） | 是 | 按需升级 mainline |
| Linux 内核 | 6.18.x-mcos | 是 | 按需升级 |

## 日志中的 USB-PLUG 2017.09

在部分启动日志中，SPL 之前还会出现一段：

```
USB-PLUG 2017.09-g8532be3569c-240909 #root (Sep 13 2024 - 10:47:54 +0800)
...
RKUSB: LUN 0, dev 0, ...
```

这是 **Rockchip USB 烧录 / 恢复模式**（插 USB 或板子尝试 USB 启动时出现）。  
之后通常会再次进行 DDR 训练，再进入正常的 SPL → U-Boot 2026 → Linux 流程。  
与第 105 行附近的 `U-Boot SPL 2017.09` 同属 rkbin 生态，用途不同（下载固件 vs
正常引导）。

## 构建与分区对应关系

### 相关脚本

| 脚本 | 产物 | 说明 |
|------|------|------|
| `scripts/mk-loader.sh` | `MiniLoaderAll.bin` | rkbin SPL + DDR，供整盘镜像 / update.img 打包 |
| `scripts/mk-uboot-img.sh` | `uboot.img` | 将 mainline `u-boot.itb` 按 2×2 MiB 槽位写入 `uboot` 分区布局 |

`mk-uboot-img.sh` 注释说明：RK3576 供应商 SPL 在 `uboot` 分区 LBA `0x4000` /
`0x5000` 扫描 FIT；mainline `u-boot.itb` 需与 SDK `fit_gen_uboot_img` 布局一致。

### GPT 分区（`parameter-ab.txt`）

与启动相关的分区：

| 分区 | 典型用途 |
|------|----------|
| （前部裸区） | `MiniLoaderAll.bin` / IDBlock |
| `uboot` | 供应商 SPL 加载的 FIT（含 BL31、OP-TEE、**mainline U-Boot**） |
| `boot_a` / `boot_b` | A/B 内核 FIT（由 U-Boot 2026 读取） |
| `system_a` / `system_b` | 根文件系统 |
| `misc` | A/B 槽位元数据（`updateEngine`） |
| `userdata` | 用户数据（MCOS 映射为 `/mnt/data`） |

### 修改启动行为时应改哪里

| 需求 | 修改位置 |
|------|----------|
| 内核 cmdline、`boot_a`/`boot_b` 选择 | `uboot.config` 中 `CONFIG_BOOTCOMMAND` |
| U-Boot 设备树、驱动、SPL 交接逻辑 | `patches/uboot/`、`uboot.config` |
| 内核、根文件系统 | `kernel.config`、`patches/linux/`、Buildroot 包 |
| 最前端 SPL / DDR | rkbin（`rockchip-pack` 包内），**一般不修改** |

## 常见问题

**Q：看到 `U-Boot SPL 2017.09` 是不是刷错版本了？**  
A：不是。只要后面出现 `U-Boot 2026.04` 并成功 `Starting kernel ...`，即为正确的
混合启动链。

**Q：能否把整个启动链都换成 U-Boot 2026？**  
A：当前 RK3576 上无法用 mainline SPL 替换 rkbin 最前端；若需全供应商栈，应改用
Rockchip SDK 整套 U-Boot，而非仅替换 SPL。

**Q：升级 U-Boot 2026 后要不要重烧 SPL？**  
A：通常只需更新 `uboot` 分区（或含 `uboot` 的整盘 / OTA 包）。`MiniLoaderAll`
仅在变更 rkbin 或分区布局时才需同步更新。

## 参考文件

- `buildroot-external/board/neardi/lb200/uboot.config` — BL33 配置与 bootcmd
- `buildroot-external/board/neardi/lb200/scripts/mk-loader.sh` — MiniLoader 打包
- `buildroot-external/board/neardi/lb200/scripts/mk-uboot-img.sh` — uboot 分区镜像
- `buildroot-external/board/neardi/lb200/README.md` — 板级移植总览
- `buildroot-external/package/rockchip-pack/README.md` — rkbin 与打包工具说明
