#!/bin/sh
# Read hardware information only. The sole output file is on USB storage.
REPORT=/mnt/us/clock-device-check.txt
umask 077
{
    echo '=== Clock device check v1 ==='
    date
    id
    uname -a
    echo '=== Display ==='
    for p in /sys/class/graphics/fb0/virtual_size /sys/class/graphics/fb0/bits_per_pixel /sys/class/graphics/fb0/rotate /sys/class/graphics/fb0/name; do
        if [ -r "$p" ]; then echo "$p"; cat "$p"; fi
    done
    echo '=== Display and RTC links ==='
    ls -ld /sys/class/graphics/fb0 /sys/class/rtc/rtc* /dev/rtc* 2>/dev/null
    echo '=== Power and RTC ==='
    for p in /sys/power/state /sys/power/wakeup_count /proc/driver/rtc /sys/class/rtc/rtc*/name /sys/class/rtc/rtc*/wakealarm; do
        if [ -r "$p" ]; then echo "$p"; cat "$p"; fi
    done
    echo '=== Battery ==='
    for p in /sys/class/power_supply/*/type /sys/class/power_supply/*/capacity /sys/class/power_supply/*/status /sys/class/power_supply/*/temp /sys/devices/system/*battery/*/battery_capacity; do
        if [ -r "$p" ]; then echo "$p"; cat "$p"; fi
    done
    command -v gasgauge-info >/dev/null 2>&1 && gasgauge-info -s
    echo '=== Temperature sensor candidates ==='
    for p in /sys/devices/virtual/i2c-adapter/i2c-*/*/papyrus_temperature /sys/class/thermal/thermal_zone*/temp; do
        if [ -r "$p" ]; then echo "$p"; cat "$p"; fi
    done
    echo '=== Available programs ==='
    for name in lipc-get-prop lipc-set-prop rtcwake ntpdate curl timeout setsid start stop eips fbset; do
        command -v "$name" 2>/dev/null || :
    done
    echo '=== FBInk files and capabilities ==='
    for p in /mnt/us/libkh/bin/fbink /mnt/us/extensions/MRInstaller/bin/K5/fbink; do
        if [ -x "$p" ]; then ls -l "$p"; "$p" -h 2>&1; fi
    done
    echo '=== Font candidates ==='
    ls -l /usr/java/lib/fonts/Palatino-Regular.ttf /usr/java/lib/fonts/Caecilia_LT_75_Bold.ttf 2>/dev/null
    echo '=== Power and rotation properties ==='
    lipc-get-prop com.lab126.powerd preventScreenSaver 2>/dev/null
    lipc-get-prop com.lab126.winmgr orientationLock 2>/dev/null
    echo '=== Completed ==='
} > "$REPORT" 2>&1
sync
exit 0
