#!/bin/bash
# =============================================================================
# RK3576 DTS 文件复制脚本
#
# 此脚本将 SDK 中的 RK3576 DTS 文件复制到 buildroot-external/kernel/v6.18.y/
# 以便主线内核构建时可以使用这些文件
#
# 使用方法:
#   cd /path/to/operating-system
#   ./board/neardi/lb200/scripts/copy_dts_files.sh
#
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# SDK 内核目录
SDK_KERNEL="${1:-/home/morty/work/share/mc_platform/rockchip_sdk/kernel-6.1}"

# 目标目录
TARGET_DIR="$(dirname "$0")/../../kernel/v6.18.y"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  RK3576 DTS 文件复制脚本${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查 SDK 内核目录是否存在
if [ ! -d "$SDK_KERNEL" ]; then
    echo -e "${RED}错误: SDK 内核目录不存在: $SDK_KERNEL${NC}"
    exit 1
fi

echo -e "\n${GREEN}Step 1: 复制 Rockchip DTS 文件...${NC}"
SDK_DTS="$SDK_KERNEL/arch/arm64/boot/dts/rockchip"

# 创建目标目录
mkdir -p "$TARGET_DIR"

# 复制所有 rk3576 相关的 DTS 文件
count=0
for f in "$SDK_DTS"/rk3576*.dtsi "$SDK_DTS"/rk3576*.dts; do
    if [ -f "$f" ]; then
        cp -v "$f" "$TARGET_DIR/"
        count=$((count + 1))
    fi
done
echo -e "  ${GREEN}[OK]${NC} 复制了 $count 个 DTS 文件"

echo -e "\n${GREEN}Step 2: 复制 dt-bindings 头文件...${NC}"
SDK_BINDINGS="$SDK_KERNEL/include/dt-bindings"
TARGET_BINDINGS="$TARGET_DIR/dt-bindings"
mkdir -p "$TARGET_BINDINGS"

# 复制 RK3576 相关的 dt-bindings
bind_count=0
for header in "$SDK_BINDINGS"/clock/rockchip,rk3576-cru.h \
              "$SDK_BINDINGS"/power/rk3576-power.h \
              "$SDK_BINDINGS"/suspend/rockchip-rk3576.h; do
    if [ -f "$header" ]; then
        cp -v "$header" "$TARGET_BINDINGS/"
        bind_count=$((bind_count + 1))
    fi
done

# 递归复制所有 rk3576 相关的 dt-bindings
find "$SDK_BINDINGS" -name "*rk3576*" -exec cp -v {} "$TARGET_BINDINGS/" \;
echo -e "  ${GREEN}[OK]${NC} dt-bindings 头文件复制完成"

echo -e "\n${GREEN}Step 3: 复制板级 DTS 文件...${NC}"
for f in "$SDK_DTS"/rk3576-neardi-lb200*.dtsi; do
    if [ -f "$f" ]; then
        cp -v "$f" "$TARGET_DIR/"
    fi
done
echo -e "  ${GREEN}[OK]${NC} 板级 DTS 文件复制完成"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  文件复制完成!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${YELLOW}验证复制的文件:${NC}"
find "$TARGET_DIR" -maxdepth 1 -name '*.dtsi' -print 2>/dev/null | head -10
