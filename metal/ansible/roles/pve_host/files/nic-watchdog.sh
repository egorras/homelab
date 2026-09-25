#!/bin/bash
# Self-heal for the e1000e (I219-LM) "Detected Hardware Unit Hang" bug.
# Runs every minute from nic-watchdog.timer. Pings the default gateway;
# after 3 and 6 failed runs resets nic0, from 10 reboots — but only if the kernel
# actually reported a NIC hang (so a dead router doesn't cause a reboot loop).
NIC=nic0
STATE=/run/nic-watchdog.fails
GW=$(ip -4 route show default | awk '{print $3; exit}')

if [ -n "$GW" ] && ping -c 3 -W 2 -q "$GW" >/dev/null 2>&1; then
    [ -f "$STATE" ] && logger -t nic-watchdog "gateway $GW reachable again"
    rm -f "$STATE"
    exit 0
fi

FAILS=$(( $(cat "$STATE" 2>/dev/null || echo 0) + 1 ))
echo "$FAILS" > "$STATE"
logger -t nic-watchdog "gateway ${GW:-?} unreachable ($FAILS)"

if [ "$FAILS" -eq 3 ] || [ "$FAILS" -eq 6 ]; then
    logger -t nic-watchdog "resetting $NIC"
    ip link set "$NIC" down; sleep 2; ip link set "$NIC" up
    ethtool -K "$NIC" tso off gso off gro off
elif [ "$FAILS" -ge 10 ]; then
    UPTIME=$(cut -d. -f1 /proc/uptime)
    if [ "$UPTIME" -gt 1800 ] && journalctl -k --since "-15min" | grep -q "Hardware Unit Hang"; then
        logger -t nic-watchdog "NIC hang persists after resets, rebooting"
        systemctl reboot
    fi
fi
