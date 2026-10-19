#!/usr/bin/env bash
# Раз в 2 с печатает: cpu% mem% memGB temp°C disk% rxB/s txB/s
pt=0; pi=0; prx=0; ptx=0
th=""; for h in /sys/class/hwmon/hwmon*; do [ "$(cat $h/name 2>/dev/null)" = coretemp ] && th="$h/temp1_input" && break; done
while :; do
  read -r _ u n s i io irq sirq st _ < /proc/stat
  idle=$((i+io)); tot=$((u+n+s+i+io+irq+sirq+st))
  dt=$((tot-pt)); cpu=0; [ $pt -gt 0 ] && [ $dt -gt 0 ] && cpu=$(( 100*(dt-(idle-pi))/dt ))
  pt=$tot; pi=$idle
  read -r mem memgb < <(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf "%d %.1f\n",100*(t-a)/t,(t-a)/1048576}' /proc/meminfo)
  temp=0; [ -n "$th" ] && temp=$(( $(cat "$th") / 1000 ))
  disk=$(df --output=pcent / | tail -1 | tr -dc 0-9)
  read -r rx tx < <(awk -F'[: ]+' 'NR>2 && $2!="lo"{r+=$3;t+=$11}END{print r+0,t+0}' /proc/net/dev)
  drx=0; dtx=0; [ $prx -gt 0 ] && drx=$(( (rx-prx)/2 )) && dtx=$(( (tx-ptx)/2 ))
  echo "$cpu $mem $memgb $temp $disk $drx $dtx"
  prx=$rx; ptx=$tx
  sleep 2
done
