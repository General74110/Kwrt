#!/bin/bash

shopt -s extglob
SHELL_FOLDER=$(dirname $(readlink -f "$0"))

# -----------------------------
# Step 0: 清理旧目录并拉最新 rockchip 源
# -----------------------------
rm -rf package/boot target/linux/rockchip
git_clone_path master https://github.com/coolsnowwolf/lede target/linux/rockchip package/boot

# -----------------------------
# Step 1: 强制 overlay/rootfs_data = 8G
# -----------------------------
ARMV8_MK="target/linux/rockchip/image/armv8.mk"
echo ">>> Force overlay/rootfs_data size to 8G"
if [ -f "$ARMV8_MK" ]; then
    sed -i '/^ROOTFS_PARTSIZE/d;/^IMAGE_SIZE/d' "$ARMV8_MK"
    sed -i '1i ROOTFS_PARTSIZE := 8192\nIMAGE_SIZE := 8192\n' "$ARMV8_MK"
else
    echo "!!! armv8.mk 不存在，overlay 未修改"
fi

# -----------------------------
# Step 2: 强制生成可启动 sysupgrade 镜像
# -----------------------------
echo ">>> Enable Kwrt-style TF bootable sysupgrade"

cat >> .config <<'EOF'
CONFIG_TARGET_ROOTFS_SQUASHFS=y
CONFIG_TARGET_IMAGES_GZIP=y
CONFIG_TARGET_IMAGES_PAD=y
CONFIG_TARGET_IMAGES_SYSGEN=y        # Kwrt 特定，包含启动元数据
CONFIG_TARGET_ROOTFS_PARTSIZE=8192
EOF

# 注：CONFIG_TARGET_IMAGES_SYSGEN=y 是关键，生成可直接启动 sysupgrade.img

# -----------------------------
# Step 3: 下载上游 patch
# -----------------------------
wget -N https://github.com/istoreos/istoreos/raw/refs/heads/istoreos-23.05/target/linux/rockchip/patches-5.15/305-r2s-pwm-fan.patch -P target/linux/rockchip/patches-6.12/
wget -N https://github.com/coolsnowwolf/lede/raw/refs/heads/master/target/linux/generic/backport-6.12/203-v6.15-drivers-base-component-add-function-to-query-the-bound.patch -P target/linux/generic/backport-6.12/

# -----------------------------
# Step 4: 清理多余模块和文件
# -----------------------------
sed -i "/KernelPackage,ptp/d" package/kernel/linux/modules/other.mk
rm -rf target/linux/rockchip/armv8/base-files/etc/uci-defaults/13_opkg_update \
       package/feeds/kiddin9/pcat-manager \
       package/feeds/kiddin9/*_QMI_WWAN

# -----------------------------
# Step 5: 驱动和默认包替换
# -----------------------------
sed -i -e 's,kmod-r8168,kmod-r8169,g' target/linux/rockchip/image/armv8.mk
sed -i -e 's,wpad-openssl,wpad-basic-mbedtls,g' target/linux/rockchip/image/armv8.mk
sed -i -e '/KERNEL_TESTING_PATCHVER/d' \
       -e 's/DEFAULT_PACKAGES +=/DEFAULT_PACKAGES += fdisk lsblk kmod-drm-rockchip luci-app-diskman/' \
       -e 's/autocore-arm/autocore/' target/linux/rockchip/Makefile
sed -i 's/Ariaboard/光影猫/' target/linux/rockchip/image/armv8.mk

echo ">>> diy.sh 完成：overlay=8G, sysupgrade 可直接 TF 启动"
