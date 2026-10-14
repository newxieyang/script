#!/bin/bash

RULE_FILE="/etc/udev/rules.d/99-oxiscan.rules"

echo "Install OXiScan USB udev rules..."

# 检查 root 权限
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

# 写入规则（建议 idVendor/idProduct 用小写）
cat > "${RULE_FILE}" << 'EOF'
SUBSYSTEM=="usb", ATTR{idVendor}=="2d38", ATTR{idProduct}=="4000", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="2d38", ATTR{idProduct}=="6010", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="2d38", ATTR{idProduct}=="7000", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="28ed", ATTR{idProduct}=="1034", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="28ed", ATTR{idProduct}=="1035", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="28ed", ATTR{idProduct}=="1036", MODE="0666"
EOF

if [ $? -ne 0 ]; then
    echo "Failed to write rules file"
    exit 1
fi

echo "USB rules installed:"
cat "${RULE_FILE}"

echo "Reload udev rules..."
udevadm control --reload-rules
udevadm trigger

echo "Done."
echo "请重新插拔设备，或重启后再测试。sed -i 's/\r$//' writeUsbRules.sh"