#!/bin/bash

#floatip_addcmd = "xxx/float_ip_add.sh eth0:0 192.168.38.222 netmask 255.255.255.0"

export PAHT=/usr/sbin:$PATH
IFCONFIG=`which ifconfig`
ARPING=`which arping`
IP=`which ip`

device="$1"
ipaddr="$2"
ipmask="$4"

num=`$IFCONFIG | grep -c $device`
if [ 0 -eq $num ]; then
	$IFCONFIG $device $ipaddr netmask $ipmask
	$IP neigh flush dev $device
	$ARPING -I $device -s $ipaddr -c 5 -p $ipmask
fi
