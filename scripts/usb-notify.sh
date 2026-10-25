#!/usr/bin/env bash
# usb-notify.sh — desktop notification when a USB device is plugged in or removed.
# Runs entirely in user space (no root required).
# Trigger source: periodic scan of /sys/bus/usb/devices, diffed against the
# previous snapshot (non-root `udevadm monitor` cannot receive events).
#
# Usage:
#   usb-notify.sh            watch for USB events and notify (service mode)
#   usb-notify.sh --test     notify for every USB device currently connected

set -u

USBIDS="/usr/share/hwdata/usb.ids"
ICON="drive-removable-media-usb"
SELF="$(basename "$0")"

log() { printf '%s: %s\n' "$SELF" "$*" >&2; }

# Look up a human-friendly product name from the usb.ids database.
usbids_name() {
    local vid="$1" pid="$2"
    [ -f "$USBIDS" ] || return 1
    awk -v v="$vid" -v p="$pid" '
        $0 ~ "^" v " " { inv=1; next }
        /^[0-9a-f]{4} / { inv=0 }
        inv && $0 ~ "^\\t" p " " { sub("^\\t" p "[[:space:]]+", ""); print; exit }
    ' "$USBIDS"
}

# Determine the display name for a sysfs usb device directory.
device_name() {
    local dev="$1" vid pid name
    vid="$(cat "$dev/idVendor" 2>/dev/null || true)"
    pid="$(cat "$dev/idProduct" 2>/dev/null || true)"
    if [ -n "$vid" ] && [ -n "$pid" ]; then
        name="$(usbids_name "$vid" "$pid")"
        [ -n "$name" ] && { echo "$name"; return; }
    fi
    # fall back to strings the device itself reports
    name="$(sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/[[:space:]]\+/ /g' "$dev/product" 2>/dev/null)"
    [ -n "$name" ] || name="$(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' "$dev/manufacturer" 2>/dev/null)"
    [ -n "$name" ] || name="USB device"
    echo "$name"
}

# Hubs (root hubs and external hubs) have maxchild > 0; skip them.
is_hub() {
    [ -f "$1/maxchild" ] && [ "$(cat "$1/maxchild" 2>/dev/null || echo 0)" -gt 0 ]
}

notify() {
    notify-send -i "$ICON" "$1" "$2" || { sleep 3; notify-send -i "$ICON" "$1" "$2"; }
}

# Whole-disk names (e.g. sdb) belonging to a USB device, via /sys/block symlinks.
usb_block_disks() {  # $1 = usb device sysfs path
    local target
    for d in /sys/block/*; do
        [ -e "$d" ] || continue
        target="$(readlink -f "$d" 2>/dev/null)"
        case "$target" in
            "$1"/*) echo "${d##*/}" ;;
        esac
    done
}

# Auto-mount readable partitions of a freshly plugged USB device (root-free,
# via the udisks2 daemon). Skips unsupported filesystems (apfs, swap, ...).
mount_usb() {  # $1 = usb device sysfs path
    local dev="$1" t=0 disks parts part disk fstype mp out name mounted
    # the storage driver needs a moment to register the block device
    disks=""
    while [ "$t" -lt 8 ]; do
        disks="$(usb_block_disks "$dev")"
        [ -n "$disks" ] && break
        sleep 1; t=$((t + 1))
    done
    [ -n "$disks" ] || { log "mount: no block device for ${dev##*/}"; return 1; }

    mounted=""
    for disk in $disks; do
        parts="$(ls "/sys/block/$disk/" 2>/dev/null | grep -E "^${disk}[0-9]+$")"
        [ -n "$parts" ] || parts="$disk"   # no partitions -> mount the disk itself
        for part in $parts; do
            fstype="$(lsblk -rno FSTYPE "/dev/$part" 2>/dev/null | head -1)"
            case "$fstype" in
                ""|swap|LVM2_member|linux_raid_member|apfs) continue ;;
            esac
            [ -n "$(lsblk -rno MOUNTPOINT "/dev/$part" 2>/dev/null | head -1)" ] && continue
            out="$(udisksctl mount -b "/dev/$part" --no-user-interaction 2>/dev/null)"
            [ -n "$out" ] || continue
            mounted="${mounted:+$mounted, }$(printf '%s' "$out" | sed 's/.* at //')"
        done
    done
    if [ -n "$mounted" ]; then
        name="$(device_name "$dev")"
        notify "Mounted" "$name at $mounted"
        log "mount: $name at $mounted"
    fi
}

# One line "devpath<TAB>name" per connected USB device (hubs/interfaces excluded).
snapshot() {
    local dev base
    for dev in /sys/bus/usb/devices/*; do
        [ -d "$dev" ] || continue
        base="$(basename "$dev")"
        case "$base" in
            usb[0-9]*|*:*) continue ;;   # root hub / interface node
        esac
        is_hub "$dev" && continue        # external hub
        printf '%s\t%s\n' "$(readlink -f "$dev")" "$(device_name "$dev")"
    done
}

watch() {
    local prev cur dev name count
    prev="$(snapshot)"
    count="$(printf '%s\n' "$prev" | sed '/^$/d' | wc -l)"
    log "watch started, $count device(s) present"

    while true; do
        sleep 1
        cur="$(snapshot)"

        # newly plugged in
        while IFS=$'\t' read -r dev name; do
            [ -n "$dev" ] || continue
            if ! grep -Fq "$dev"$'\t' <<< "$prev"; then
                notify "USB Connected" "$name"
                log "add: ${dev##*/} -> $name"
                mount_usb "$dev" &   # auto-mount in the background
            fi
        done <<< "$cur"

        # unplugged / ejected (name comes from the previous snapshot,
        # since the sysfs directory is already gone)
        while IFS=$'\t' read -r dev name; do
            [ -n "$dev" ] || continue
            if ! grep -Fq "$dev"$'\t' <<< "$cur"; then
                notify "USB Disconnected" "$name"
                log "remove: ${dev##*/} -> $name"
            fi
        done <<< "$prev"

        prev="$cur"
    done
}

test_mode() {
    local dev base
    for dev in /sys/bus/usb/devices/*; do
        [ -d "$dev" ] || continue
        base="$(basename "$dev")"
        case "$base" in
            usb[0-9]*|*:*) continue ;;
        esac
        is_hub "$dev" && continue
        notify "USB Connected" "$(device_name "$dev")"
    done
    log "test mode: sent notifications for all connected devices"
}

case "${1:-}" in
    --test) test_mode ;;
    *)      watch ;;
esac
