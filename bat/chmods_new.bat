

adb root
adb remount
adb shell "setenforce 0"
adb shell "chmod 777 /dev/oxi_fp"
adb shell "chmod 777 /dev/luoji"
adb shell "chmod 777 /dev/qseecom"

adb shell "chmod 777 /data"

adb shell "mv vendor/lib64/liboxi.so vendor/lib64/liboxi.so_bak"
adb shell "mv vendor/lib64/hw/fingerprint.oxifod.default.so vendor/lib64/hw/fingerprint.oxifod.default.so_bak"

adb shell mkdir /data/oxi/
adb shell mkdir /data/oxi/bin
adb shell mkdir /data/oxi/cali
adb shell mkdir /data/oxi/enroll
adb shell mkdir /data/oxi/auth
adb shell mkdir /data/oxi/test
adb shell mkdir /data/oxi/template
adb shell mkdir /data/oxi/capture
adb shell mkdir /data/oxi/log
adb shell mkdir /data/oxi/analysis

adb shell chmod 777 -R  /data/oxi


adb shell "chmod 777 /dev/input/event0"
adb shell "chmod 777 /dev/input/event1"
adb shell "chmod 777 /dev/input/event2"
adb shell "chmod 777 /dev/input/event3"
adb shell "chmod 777 /dev/input/event4"
adb shell "chmod 777 /dev/input/event5"
adb shell "chmod 777 /dev/input/event6"
adb shell "chmod 777 /dev/input/event7"
adb shell "chmod 777 /dev/input/event8"
adb shell "chmod 777 /dev/input/event9"
adb shell "chmod 777 /dev/input/event10"


adb shell "chmod 777 /sys/lcm/oled_hbm"
::adb shell "echo 4 > /sys/lcm/oled_hbm"
adb shell "chmod 777 /sys/class/leds/lcd_backlight0/brightness"
::adb shell "echo 1 > /sys/kernel/oppo_display/hbm"


echo "done"
pause
