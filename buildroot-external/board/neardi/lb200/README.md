# Neardi RK3576 LB200 Board Porting Guide

## 概述

本文档描述如何将 Neardi RK3576 LB200 Board 从 Rockchip SDK (kernel-6.1) 移植到主线内核 (kernel-6.18+)，使用 buildroot-external 作为构建系统。

## 硬件规格

| 组件 | 型号/规格 |
|------|----------|
| SoC | Rockchip RK3576 |
| CPU | ARM Cortex-A76 + Cortex-A55 |
| GPU | Mali-G52 MC4 |
| NPU | 6 TOPS |
| 内存 | LPDDR4x |
| 存储 | eMMC, UFS, SPI Flash |
| 网络 | 双千兆以太网 (YT8521 PHY) |
| WiFi/BT | Seekwave SV6160 (SDIO) |
| 显示 | HDMI, DP, eDP, MIPI DSI |
| USB | USB-C (DP Alt Mode), USB 3.0 |
| 其他 | CAN, RS485, PCIe, RTC |

## Rockchip SDK 分区与镜像（LB200 专用）

LB200 使用 **Rockchip `parameter-ab.txt` 布局**，不再生成 MCOS 通用 `mcos-*.raucb` 镜像。相关工具与源码已 vendoring 到 `buildroot-external/package/`：

- `rockchip-recovery` — `updateEngine` 源码
- `rockchip-pack` — `afptool`、`rkImageMaker`、`boot_merger` + RK3576 `rkbin`

构建时启用 `BR2_PACKAGE_HOST_ROCKCHIP_PACK`（已在 `mc_neardi_lb200_defconfig` 中打开），**无需** `mc_platform/rockchip_sdk`。

### 构建产物（`output/images/`）

| 文件 | 用途 |
|------|------|
| `mcos_mc-neardi-lb200-<ver>.img` | 整盘 GPT 镜像（`dd` / RKDevTool 下载镜像） |
| `mcos_mc-neardi-lb200-<ver>-ab.img` | Rockchip `update.img`（RKDevTool 升级固件） |
| `mcos_mc-neardi-lb200-<ver>-ab-ota.img` | OTA 包（`updateEngine` / U 盘升级） |

### 首次刷机

- **RKDevTool**：加载 `*-ab.img` →「升级固件」
- 或 **下载镜像**：写入 `mcos_*.img` 整盘镜像

### 日常升级（无 SD 卡）

1. 将 `*-ab-ota.img` 重命名或复制为 U 盘上的 `update-ota.img` 或 `update.img`
2. 插入 USB Host 口，挂载到 `/mnt/udisk`
3. 执行：`mcos-udisk-update`  
   或：`updateEngine --update --image_url=/mnt/udisk/update-ota.img --reboot`

### 分区说明

`uboot` / `misc` / `boot_a|b` / `system_a|b` / `oem` / `userdata`（见 `board/neardi/lb200/parameter-ab.txt`）。  
根文件系统在 `system_a`，Docker 数据在 `userdata`（兼容层映射到 `/mnt/data`）。

启动链（供应商 SPL 2017.09 + mainline U-Boot 2026）详见
[`Documentation/lb200-boot-chain.md`](../../../../Documentation/lb200-boot-chain.md)。

---

```
buildroot-external/
├── configs/
│   └── mc_neardi_lb200_defconfig     # Buildroot defconfig
├── board/neardi/lb200/
│   ├── meta                          # 板级元数据
│   ├── mcos-hook.sh                  # 构建 hook 脚本
│   ├── kernel.config                 # 内核配置覆盖
│   ├── uboot-boot.ush                # U-Boot boot 脚本
│   ├── uboot.config                  # U-Boot 配置覆盖
│   ├── boot-env.txt                  # 启动环境变量
│   ├── cmdline.txt                   # 内核命令行
│   └── patches/linux/                # 内核补丁
│       ├── README.skwifi             # SKW 驱动说明
│       ├── integrate_skwifi.sh       # SKW 驱动集成脚本
│       └── 0001-*.patch              # YT8521 PHY 补丁
├── kernel/v6.18.y/
│   ├── kernel-arm64-rockchip.config  # 基础内核配置
│   ├── rk3576-mc-neardi-lb200.dts    # 板级设备树
│   └── (其他配置和补丁)
└── package/skwifi/
    ├── Config.in                     # Buildroot 包配置
    ├── skwifi.mk                     # 构建规则
    ├── fw/                           # 固件目录（需从 SDK 复制）
    │   └── README                    # 固件说明
    └── nv/                           # NV 文件目录（需从 SDK 复制）
        └── README                    # NV 文件说明
```

## 移植步骤

### 步骤 1: 准备工作

```bash
# 进入项目目录
cd /home/morty/work/share/mc_os/operating-system

# 确认 SDK 位置
ls -la ../mc_platform/rockchip_sdk/
```

### 步骤 2: 复制固件文件（必须）

SKW WiFi 驱动需要固件文件，必须从 SDK 复制：

```bash
# 复制 WiFi 固件
cp ../mc_platform/rockchip_sdk/external/rkwifibt/firmware/*.bin \
   buildroot-external/package/skwifi/fw/

# 复制 NV 文件
cp ../mc_platform/rockchip_sdk/external/rkwifibt/nv/*.bin \
   buildroot-external/package/skwifi/nv/
```

### 步骤 3: 集成 SKW WiFi 驱动（必须）

```bash
# 运行集成脚本
cd buildroot-external/kernel/v6.18.y
bash ../../board/neardi/lb200/patches/linux/integrate_skwifi.sh .

# 或者手动复制驱动文件
cp -r ../../mc_platform/rockchip_sdk/kernel-6.1/drivers/net/wireless/rockchip_wlan/skwifi \
      drivers/net/wireless/rockchip_wlan/
cp -r ../../mc_platform/rockchip_sdk/kernel-6.1/drivers/misc/seekwaveplatform_v20 \
      drivers/misc/
```

### 步骤 4: 构建系统配置

```bash
# 使用新的 defconfig
cd buildroot-external
make mc_neardi_lb200_defconfig

# 或者更新现有配置
make menuconfig
# 选择:
#   Target options -> Target Architecture -> AArch64 (ARM 64-bit)
#   Build options -> Location to save buildroot config -> configs/mc_neardi_lb200_defconfig
```

### 步骤 5: 构建

```bash
# 构建整个系统
make

# 构建完成后，固件会被自动安装到 rootfs
```

## 功能适配状态

### ✅ 已完成适配

| 功能 | 状态 | 说明 |
|------|------|------|
| CPU/内存 | ✅ 支持 | 主线内核完全支持 |
| eMMC/UFS | ✅ 支持 | 已启用 |
| HDMI 显示 | ✅ 支持 | 需要测试 VOP 路由 |
| USB-C/DP | ✅ 支持 | FUSB302 + DP Alt Mode |
| PCIe | ✅ 支持 | 已配置 |
| CAN/RS485 | ✅ 支持 | 已配置 |
| GPIO LED | ✅ 支持 | 已配置 |
| RTC | ✅ 支持 | hym8563 |
| SPI Flash | ✅ 支持 | sfc1 |

### ⚠️ 需要测试

| 功能 | 状态 | 说明 |
|------|------|------|
| 以太网 | ⚠️ 测试 | YT8521 PHY，需要测试地址 0x1 |
| HDMI 音频 | ⚠️ 测试 | 可能有 VOP 路由差异 |
| 以太网 tx_delay | ⚠️ 配置 | SDK 值 0x21/0x20 可能需要调整 |

### ❌ 需要额外工作

| 功能 | 状态 | 说明 |
|------|------|------|
| WiFi/BT | ❌ 需移植 | SKW 驱动需要集成 |
| 固件 | ❌ 需复制 | 必须从 SDK 复制固件文件 |

## 设备树配置说明

### 串口控制台

```dts
chosen {
    bootargs = "earlycon=uart8250,mmio32,0x2ad40000 console=ttyS2,1500000n8 ...";
    stdout-path = "serial2:1500000n8";
};
```

注意：从 SDK 的 `ttyFIQ0` 改为标准 `ttyS2`

### 以太网配置

```dts
&gmac0 {
    tx_delay = <0x21>;  // 从 SDK 移植
    phy-handle = <&rgmii_phy0>;
};

&mdio0 {
    rgmii_phy0: phy@1 {
        reg = <0x1>;  // 先尝试标准地址，如不工作改为 0x0
    };
};
```

### WiFi 配置

```dts
&sdio {
    mmc-pwrseq = <&sdio_pwrseq>;
    status = "okay";
};

&{/} {
    sdio_pwrseq: sdio-pwrseq {
        compatible = "mmc-pwrseq-simple";
        reset-gpios = <&gpio1 RK_PC2 GPIO_ACTIVE_LOW>;
    };

    seekwcn_boot: seekwcn-boot {
        compatible = "seekwave,sv6160";
        dma_type = <1>;
    };
};
```

## 常见问题

### Q1: 以太网不工作

**症状**: `eth0` 无法获取 IP 地址

**解决步骤**:
1. 检查 PHY 连接: `dmesg | grep eth`
2. 尝试不同 PHY 地址: 将 `reg = <0x1>` 改为 `reg = <0x0>`
3. 检查 tx_delay: 尝试 `0x10`, `0x20`, `0x21`
4. 检查硬件连接

### Q2: WiFi 模块无法加载

**症状**: `skw_cfg80211` 模块加载失败

**解决步骤**:
1. 确认固件文件已复制: `ls /lib/firmware/seekwave/`
2. 检查 SDIO 接口: `ls /sys/bus/sdio/devices/`
3. 查看内核日志: `dmesg | grep -i skw`
4. 确认驱动已编译: `modinfo skw_cfg80211`

### Q3: HDMI 不显示

**症状**: 连接 HDMI 但无显示

**解决步骤**:
1. 检查 HDMI 连接
2. 查看显示日志: `dmesg | grep -i hdmi`
3. 检查 VOP 路由配置
4. 尝试不同的显示模式

## 后续优化

### 性能优化

1. **以太网性能**: 调整 `tx_delay` 和 `rx_delay`
2. **WiFi 性能**: 调整天线配置和功率设置
3. **显示性能**: 优化 VOP 缓存设置

### 功耗优化

1. **CPU 调频**: 配置 `cpufreq` governor
2. **GPU 调频**: 配置 `devfreq`
3. **WiFi 功耗**: 启用 `keep-power-in-suspend`

### 功能扩展

1. **摄像头**: 添加 CSI 接口支持
2. **显示**: 添加双屏显示支持
3. **音频**: 添加 PDM 麦克风支持

## 参考资料

- [Rockchip RK3576 Datasheet](https://www.rock-chips.com/)
- [Mainline Linux Kernel](https://www.kernel.org/)
- [Buildroot Documentation](https://buildroot.org/docs.html)
- [Seekwave SV6160 Documentation](SDK 文档)

## 联系方式

技术支持: support@neardi.com
