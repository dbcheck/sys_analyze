#!/bin/bash

#floatip_delcmd = "xxx/float_ip_del.sh eth0:0 down"

export PAHT=/usr/sbin:$PATH
IFCONFIG=`which ifconfig`

device="$1"

num=`$IFCONFIG | grep -c $1`
if [ $num -eq 1 ]; then
	$IFCONFIG $device down
fi

