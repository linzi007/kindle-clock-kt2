#!/bin/sh
# KT2-specific clock, following the KUAL + FBInk approach of mattzzw/kindle-clock.
# Hardware verified on a KT2 (C6), firmware 5.12.2.2, 600x800 portrait display.
BASE=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 1
MODE=${1:-preview}
case "$MODE" in preview|start) ;; *) exit 1 ;; esac
export TZ=CST-8 LC_ALL=C
FBINK="$BASE/bin/fbink"
FONT=/usr/java/lib/fonts/Palatino-Regular.ttf
STATE="$BASE/runtime"
LOCK=/tmp/xiamen-clock.lock
STOP=/tmp/xiamen-clock.stop
BATTERY=/sys/class/power_supply/max77696-battery/capacity
mkdir -p "$STATE"
if ! mkdir "$LOCK" 2>/dev/null; then
    echo 'Clock is already running; leaving it alone.'
    exit 0
fi
echo "$$" > "$LOCK/pid"
rm -f "$STOP"
GUI_STOPPED=0
OLD_SS=$(lipc-get-prop com.lab126.powerd preventScreenSaver 2>/dev/null)
case "$OLD_SS" in 0|1) ;; *) OLD_SS=0 ;; esac
OLD_WIFI=$(lipc-get-prop com.lab126.cmd wirelessEnable 2>/dev/null)
case "$OLD_WIFI" in 0|1) ;; *) OLD_WIFI=unknown ;; esac
WIFI_CHANGED=0
cleanup() {
    trap '' HUP INT TERM
    lipc-set-prop com.lab126.powerd preventScreenSaver "$OLD_SS" >/dev/null 2>&1
    if [ "$WIFI_CHANGED" = 1 ] && [ "$OLD_WIFI" != unknown ]; then
        lipc-set-prop com.lab126.cmd wirelessEnable "$OLD_WIFI" >/dev/null 2>&1
    fi
    if [ "$GUI_STOPPED" = 1 ]; then start lab126_gui; fi
    rm -f "$LOCK/pid" "$STOP"
    rmdir "$LOCK" 2>/dev/null
    echo "$(date '+%Y-%m-%d %H:%M:%S %Z'): returned to Kindle UI"
}
trap cleanup EXIT
trap 'exit 0' HUP INT TERM

echo "$(date '+%Y-%m-%d %H:%M:%S %Z'): starting $MODE"
# Compute-only checks do not paint anything; fail before stopping the GUI.
if [ ! -x "$FBINK" ] || [ ! -r "$FONT" ] ||
   ! "$FBINK" -q -t "regular=$FONT,px=144,top=180,bottom=350,left=20,right=20,notrunc,compute" -- '23:59' ||
   ! "$FBINK" -q -t "regular=$FONT,px=64,top=535,bottom=170,left=24,right=24,notrunc,compute" -- '-- C' ||
   ! "$FBINK" -q -t "regular=$FONT,px=64,top=535,bottom=170,left=24,right=24,notrunc,compute" -- '-12C'; then
    echo 'FBInk / font preflight failed.'
    exit 1
fi
if ! stop lab126_gui; then echo 'Unable to stop stock UI; aborting.'; exit 1; fi
GUI_STOPPED=1
sleep 3
if ! lipc-set-prop com.lab126.powerd preventScreenSaver 1; then exit 1; fi

text() {
    # getopt parses leading '-' in placeholder/negative temperatures as options
    # unless the end-of-options marker is supplied explicitly.
    "$FBINK" -q -b -m -t "regular=$FONT,px=$1,top=$2,bottom=$3,left=24,right=24" -- "$4"
}

CONDITION='Weather unavailable'
TEMPERATURE='-- C'
WEATHER_AT='--:--'
if [ -s "$STATE/weather.txt" ]; then
    CONDITION=$(sed -n '1p' "$STATE/weather.txt")
    TEMPERATURE=$(sed -n '2p' "$STATE/weather.txt")
    WEATHER_AT=$(sed -n '3p' "$STATE/weather.txt")
fi
draw() {
    FLASH=$1
    "$FBINK" -q -b -k || return 1
    text 24 65 690 'XIAMEN  /  CHINA' || return 1
    text 144 180 350 "$(date '+%H:%M')" || return 1
    text 28 355 385 "$(date '+%A, %d %B %Y')" || return 1
    text 32 465 280 "$CONDITION" || return 1
    text 64 535 170 "$TEMPERATURE" || return 1
    BAT=$(cat "$BATTERY" 2>/dev/null)
    case "$BAT" in ''|*[!0-9]*) BAT='--' ;; esac
    text 18 665 100 "Weather $WEATHER_AT  |  Battery $BAT%" || return 1
    if [ "$MODE" = preview ]; then
        text 17 732 35 'TEST: returns to Home after 2 minutes' || return 1
    else
        text 17 732 35 'Hold power to restart and leave clock' || return 1
    fi
    if [ "$FLASH" = 1 ]; then "$FBINK" -q -f -w -s; else "$FBINK" -q -w -s; fi
}
ensure_wifi() {
    WIFI_STATE=$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null)
    echo "Wi-Fi before weather request: ${WIFI_STATE:-unknown}"
    if [ "$WIFI_STATE" != CONNECTED ]; then
        # The Wi-Fi credentials must have been configured in Kindle Settings.
        # Enabling the radio cannot join a network that has not been saved.
        if lipc-set-prop com.lab126.cmd wirelessEnable 1 >>"$STATE/weather-error.txt" 2>&1; then
            WIFI_CHANGED=1
        fi
        WIFI_TRIES=0
        while [ "$WIFI_TRIES" -lt 20 ]; do
            WIFI_STATE=$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null)
            [ "$WIFI_STATE" = CONNECTED ] && break
            sleep 1
            WIFI_TRIES=$((WIFI_TRIES + 1))
        done
    fi
    printf 'Wi-Fi state: %s\n' "${WIFI_STATE:-unknown}" >> "$STATE/weather-error.txt"
    if [ "$WIFI_STATE" != CONNECTED ]; then
        echo 'Wi-Fi is not connected. Connect a saved network in Kindle Settings.' >> "$STATE/weather-error.txt"
        echo "Weather skipped: Wi-Fi state ${WIFI_STATE:-unknown}"
        return 1
    fi
    # Record resolver configuration only, without Wi-Fi names or credentials.
    sed -n '/^[[:space:]]*nameserver[[:space:]]/p' /etc/resolv.conf >> "$STATE/weather-error.txt" 2>/dev/null
    return 0
}
weather() {
    : > "$STATE/weather-error.txt"
    ensure_wifi || return 1
    # Fixed location, metric units, ASCII English conditions; no API key required.
    VALUE=$(curl -fLsS --connect-timeout 5 --max-time 12 \
        'https://wttr.in/Xiamen?m&format=%C%7C%t' 2>>"$STATE/weather-error.txt") || return 1
    # Reject HTML, multi-line or malformed replies; never execute weather data.
    case "$VALUE" in *'|'*) ;; *) return 1 ;; esac
    C=${VALUE%%|*}; T=${VALUE#*|}
    case "$C" in ''|*[!a-zA-Z\ \-]*) return 1 ;; esac
    [ "${#C}" -le 32 ] || return 1
    T=$(printf '%s' "$T" | sed 's/°C/C/;s/^+//')
    case "$T" in *C) N=${T%C} ;; *) return 1 ;; esac
    case "$N" in -*) N=${N#-} ;; esac
    case "$N" in ''|*[!0-9]*) return 1 ;; esac
    CONDITION=$C; TEMPERATURE=$T; WEATHER_AT=$(date '+%H:%M')
    printf '%s\n%s\n%s\n' "$CONDITION" "$TEMPERATURE" "$WEATHER_AT" > "$STATE/weather.txt.tmp"
    mv "$STATE/weather.txt.tmp" "$STATE/weather.txt"
    echo "Weather updated: $CONDITION / $TEMPERATURE"
}

BEGAN=$(date +%s)
ENDS=$((BEGAN + 120))
LAST_WEATHER=0
LAST_ATTEMPT=0
LAST_MINUTE=''
while [ ! -f "$STOP" ]; do
    NOW=$(date +%s)
    if [ "$MODE" = preview ] && [ "$NOW" -ge "$ENDS" ]; then break; fi
    MINUTE=$(date '+%Y%m%d%H%M')
    if [ "$MINUTE" != "$LAST_MINUTE" ]; then
        FLASH=0
        case "$(date '+%M')" in *0|*5) FLASH=1 ;; esac
        [ -z "$LAST_MINUTE" ] && FLASH=1
        draw "$FLASH" || exit 1
        LAST_MINUTE=$MINUTE
    fi
    # Retry failed requests at most every 5 minutes; successful data every hour.
    if [ $((NOW - LAST_WEATHER)) -ge 3600 ] && [ $((NOW - LAST_ATTEMPT)) -ge 300 ]; then
        LAST_ATTEMPT=$NOW
        # Clock can run offline; unavailable weather is explicitly shown.
        if weather; then LAST_WEATHER=$(date +%s); draw 0 || exit 1; fi
    fi
    NOW=$(date +%s)
    WAIT=$((60 - NOW % 60))
    if [ "$MODE" = preview ] && [ $((NOW + WAIT)) -gt "$ENDS" ]; then WAIT=$((ENDS - NOW)); fi
    [ "$WAIT" -gt 0 ] || continue
    # Deep suspend is disabled: RTC auto-wake failed on this KT2.
    sleep "$WAIT"
done
exit 0
