#!/bin/sh

# -------------------------------------------------------------------
# this script use gdb to attach process to print stack of per thread.
# leapking, 2018-09-24
# Move to: https://github.com/dbcheck/pstack
# -------------------------------------------------------------------

#
# print all thread stack to a file
#(gdb) set logging file /tmp/test.txt
#(gdb) set logging on
#(gdb) thread apply all bt
#

PID=$1
SYMBOLFILE=$2

if [ x"$PID" = x -o ! -r /proc/$PID ]; then
        echo "Usage: `basename $0 .sh` {PID} [symbol]" 1>&2
        echo "PID $PID is must exist"
        exit 1
elif [ x"$SYMBOLFILE" != x ]; then
        if [ ! -e $SYMBOLFILE ]; then
                echo "Usage: `basename $0 .sh` {PID} [symbol]" 1>&2
                echo "symbol file: $SYMBOLFILE is not exist"
                exit 1
        fi
	SYMBOLFILE="symbol-file $SYMBOLFILE"
fi

# GDB doesn't allow "thread apply all bt" when the process isn't
# threaded; need to peek at the process to determine if that or the
# simpler "bt" should be used.

backtrace="bt"
if test -d /proc/$1/task ; then
    # Newer kernel; has a task/ directory.
    if test `/bin/ls /proc/$1/task | /usr/bin/wc -l` -gt 1 2>/dev/null ; then
	backtrace="thread apply all bt"
    fi
elif test -f /proc/$1/maps ; then
    # Older kernel; go by it loading libpthread.
    if /bin/grep -e libpthread /proc/$1/maps > /dev/null 2>&1 ; then
	backtrace="thread apply all bt"
    fi
fi

GDB=${GDB:-/usr/bin/gdb}

if $GDB -nx --quiet --batch --readnever > /dev/null 2>&1; then
    readnever=--readnever
else
    readnever=
fi

# Run GDB, strip out unwanted noise.
printstack()
{
$GDB --quiet $readnever --nx /proc/$PID/exe $1 <<EOF 2>&1 |
set width 0
set height 0
set pagination no
set scheduler-locking off
$SYMBOLFILE
$backtrace
detach
quit
EOF
/bin/sed -n \
    -e 's/(gdb) //g' \
    -e '/^#/p' \
    -e '/^ /p' \
    -e '/^Thread/p'
}

# Main
# ---------------------------
trap "exit" HUP INT QUIT TSTP

if [ ${#backtrace} -eq 2 ]; then
	i=0
	for id in $(ls /proc/$PID/task)
	do
		i=$((i+1))
		echo "Thread $i (Thread 0x0000000 (LWP $id)):"
		printstack $id
	done
else
	printstack $PID
fi
