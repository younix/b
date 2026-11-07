#!/bin/sh

set -eu

all=0
clean=0
full=0
install=0
jobs=`sysctl -n hw.ncpuonline`
update=
bsd=
reboot=0
doas="doas"
src=${USR_SRC:-/usr/src}
compile=$src/sys/arch/`machine`/compile

if [ `whoami` = 'root' ]; then
	doas=""
fi

config_list=

args=`getopt acfij:ru: $*`
if [ $? -ne 0 ]
then
	echo 'Usage: b [-afri]'
	exit 2
fi
set -- $args
while [ $# -ne 0 ]
do
	case "$1"
	in
	-a)
		all=1; shift;;
	-c)
		clean=1; shift;;
	-f)
		full=1; shift;;
	-i)
		install=1; shift;;
	-j)
		jobs="$2"; shift; shift;;
	-r)
		install=1; reboot=1; shift;;
	-u)
		update="$2"; install=1; shift; shift;;
	--)
		shift; break;;
	esac
done

if [ $clean -eq 1 ]; then
	find $src \( -name '.#*' -o -name '*.orig' -o -name '*.rej' \) -delete
	exit
fi

if [ $all -eq 1 ]; then
	for dir in `ls $compile`; do
		if [ -d $compile/$dir -a $dir != "GENERIC.MP" -a $dir != "CVS" ]; then
			config_list="$config_list $dir"
		fi
	done
fi

# build GERNIC.MP at least, to use it afterwards
config_list="$config_list GENERIC.MP"

for config in $config_list; do
	cd $compile/$config

	if [ ! -d obj ]; then
		make obj
	fi

	if [ $full -eq 1 -o ! -s obj/Makefile ]; then
		make config
		make clean
		start=`date +%s`
	fi

	make -j $jobs

	if [ $full -eq 1 ]; then
		end=`date +%s`
		date=`date +%F_%T`
		printf "%s\t%s\t%-10s\t%s\n" $date "`uname -nr`" $config \
		    $((end - start)) >> $HOME/.build-time.log
	fi

	bsd=$compile/$config/obj/bsd
done

if [ $install -eq 1 ]; then
	if [ -n "$update" ]; then
		scp $bsd $update:/
	else
		$doas make install
	fi
fi

if [ $reboot -eq 1 ]; then
	if [ -n "$update" ]; then
		ssh $update shutdown -r now boot new kernel
	else
		$doas shutdown -r now boot new kernel
	fi
fi
