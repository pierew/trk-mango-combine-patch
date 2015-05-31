#!/bin/bash

grep -q debugging /proc/cmdline && set -x

grep -q allro /proc/cmdline && echow "Setting ALL local disks read-only" && /bin/blockdevallro >/dev/null

TRKMOUNTDIR=`cat /etc/trkmountdir`

function SearchCd {
# All other things we can check if we 're not running from PXE
# Check cd-rom drives in /proc/sys/dev/cdrom/info
TRKLABEL=`cat /proc/cmdline | tr " " "\n" | grep -i vollabel | cut -d "=" -f 2`
if [ r$TRKLABEL == r ]; then TRKLABEL=TRK_3.4; fi
cdcount=`grep name /proc/sys/dev/cdrom/info | wc -w`
cdcount=$[$cdcount-2]
echow "Trying to find TRK on your $cdcount CD-drive(s)"
cddrives=`grep name /proc/sys/dev/cdrom/info| sed -e s'/drive name://'`
for j in $cddrives; do if [ "$TRKLABEL"  == "`dd if=/dev/$j bs=1 skip=32808 count=16  2>/dev/null| tr -d " "`" ]; then echo $j > /etc/trkcd; fi;  
done;
# Check if TRK was found on CD, otherwise look on writable storage
if [ -s /etc/trkcd ]; then
c=`cat /etc/trkcd`
# Checking for the need to put TRK completely in memory

  if [ "$TRKMOUNTDIR" = "/trktmp" ]; then 
   mount -r -t iso9660 /dev/$c /trktmp
   echow "TRK 3.4 found in /dev/$c, copy files in memory, eject CD later" 
   mkdir /dev/shm/trkinmem && \
   cp -a $TRKMOUNTDIR/trk3/trkramfs /dev/shm/trkinmem/ 
   mount -t squashfs -o loop,ro /dev/shm/trkinmem/trkramfs /linkedfs-ro/
   #exit 0;
  else
  mount -r -t iso9660 /dev/$c /trk
   echow "TRK 3.4 found in CD /dev/$c, attaching additional files"
   mount -t squashfs -o loop,ro /trk/trk3/trkramfs /linkedfs-ro/
   #exit 0;
  fi; 
fi;
 } # End function SearchCd
 
 function MountTrkRW {
  mkdir -p /dev/shm/trkrwbr
  grep -q aufs /proc/filesystems
  if [ $? = 0 ]; then
  echo "Mounting TRK read-write with aufs"
  mount -t aufs -o br=/dev/shm/trkrwbr:/linkedfs-ro=ro none /linkedfs
  else 
  echo "No aufs support in kernel found, mounting TRK read-only"  
  #funionfs -o dirs=/linkedfs-ro=RO:/dev/shm/trkrwbr -o allow_other none /linkedfs || bash # In case something still goes wrong
  rm -rf /linkedfs && ln -s /linkedfs-ro /linkedfs || bash
  fi;
  # Only exit when CD or writable storage device or NFS mount has been found
  if [ -s /etc/trkcd -o -s /etc/trkhd -o -s /etc/trknfs ]; then
  exit 0;
  fi;
  } # MountTrkRW

# Check first if we 're running from network

TRKNFS=`cat /proc/cmdline | tr " " "\n" | grep -i trknfs | cut -d "=" -f 2 2>/dev/null`
if [ "r$TRKNFS" != "r" ]; then
	egrep 'eth|bond|usb' /proc/net/dev | cut -d ":" -f 1 | cut -b 3- > /var/run/nics
	egrep 'eth|bond|usb' /etc/modprobe.conf 2>/dev/null  | cut -d " "  -f 2 >> /var/run/nics 2>/dev/null
	cat /var/run/nics | sort | uniq > /var/run/nics~
	mv -f /var/run/nics~ /var/run/nics
	cat /var/run/nics | while read j;
	do echo "Trying to get an IP-address for $j"
	/sbin/dhclient -q -lf /var/lib/dhcp/dhclient.leases -1 $j 2>/dev/null && touch /var/run/networkup
	sleep 2
	done;
		
echo "Starting portmapper"
        /sbin/portmap
echo "Starting rpc.statd"
	/sbin/rpc.statd
	echo "$TRKNFS" > /etc/trknfs
if [ "$TRKMOUNTDIR" = "/trktmp" ]; then
        echow "Looks like we 're booting from network, copying TRK in memory"
	mkdir -p /linkedfs/lib/modules/`uname -r`
	touch /linkedfs/lib/modules/`uname -r`/modules.dep
        mount.nfs $TRKNFS $TRKMOUNTDIR 2>/dev/null || mount.nfs $TRKNFS $TRKMOUNTDIR  2>/dev/null
	mkdir /dev/shm/trkinmem && \
	cp -a $TRKMOUNTDIR/trk3/trkramfs /dev/shm/trkinmem/
	mount -t squashfs -o loop,ro /dev/shm/trkinmem/trkramfs /linkedfs-ro/ && MountTrkRW
	if [ $? != 0 ]; then
	echow "Something's wrong in startup, dropping to a shell, stop booting"
	echow "Use dmesg | more to rerun your startup sequence and report the error on the forum"
	bash
	fi;
	exit 0
else
        echow "Looks like we 're booting from network, mounting $TRKNFS on /trk"
        mkdir -p /linkedfs/lib/modules/`uname -r`
        touch /linkedfs/lib/modules/`uname -r`/modules.dep
	mount.nfs $TRKNFS $TRKMOUNTDIR 2>/dev/null || mount.nfs $TRKNFS $TRKMOUNTDIR 2>/dev/null
	mount -t squashfs -o loop,ro /trk/trk3/trkramfs /linkedfs-ro/ && MountTrkRW
	if [ $? != 0 ]; then
	echow "Something's wrong in startup, dropping to a shell, stop booting"
	echow "Use dmesg | more to rerun your startup sequence and report the error on the forum"
	bash
	fi;
	exit 0
fi;
fi;

 SearchCd
 if [ -s /etc/trkcd ]; then
 MountTrkRW
 fi;
# Try finding TRK on writable storage

echow "TRK not found on CD, checking harddisks and USB sticks (sleep 5 secs let them settle in)"
echow "Don't worry when errors of tune2fs occur, it's normal when they scan a non EXT Partition"
sleep 5
TRKLABEL=`cat /proc/cmdline | tr " " "\n" | grep -i vollabel | cut -d "=" -f 2`
if [ r$TRKLABEL == r ]; then TRKLABEL="TRK_3-4"; fi
export hddrives=`cat /proc/partitions | awk '{print $4}' | dd bs=1 skip=6 2>/dev/null`
for h in $hddrives; do
	echo -e "drive c: file=\"/dev/$h\"\nmtools_skip_check=1" > /etc/mtools.conf
	if [ "$TRKLABEL" == "`mlabel -s c: 2>/dev/null | cut -d " " -f 5 | tr -d " "`" ]; then
		echo $h > /etc/trkhd
		touch /var/run/runfromhd
	elif [ "$TRKLABEL" == "`tune2fs -l /dev/$h | grep 'Filesystem volume name' | awk '{print  $4}'`" ]; then
		echo $h > /etc/trkhd
		touch /var/run/runfromhd
	fi
done;
if [ "r$h" = "r" ] ; then 
echow "Drive with TRK not found yet, trying again (sleeping 10 more seconds)"
sleep 10
export hddrives=`cat /proc/partitions | awk '{print $4}' | dd bs=1 skip=6 2>/dev/null`
for h in $hddrives; do 
	echo -e "drive c: file=\"/dev/$h\"\nmtools_skip_check=1" > /etc/mtools.conf
	if [ "$TRKLABEL" == "`mlabel -s c: 2>/dev/null | cut -d " " -f 5 | tr -d " "`" ]; then
		echo $h > /etc/trkhd
		touch /var/run/runfromhd
	elif [ "$TRKLABEL" == "`tune2fs -l /dev/$h 2>/dev/null | grep 'Filesystem volume name' | awk '{print  $4}'`" ]; then
		echo $h > /etc/trkhd
		touch /var/run/runfromhd
	fi
done;
fi;
TRKHD=`cat /etc/trkhd`
TRKMOUNTDIR=`cat /etc/trkmountdir`
if [ -s /etc/trkhd ]; then
 if [ "$TRKMOUNTDIR" = "/trktmp" ]; then
 echow "TRK 3.4 found on writable storage /dev/$TRKHD, copy files in memory, will unmount/detach your drive later" 
 mount /dev/$TRKHD /trktmp	 
 mkdir /dev/shm/trkinmem && \
 cp -a $TRKMOUNTDIR/trk3/trkramfs /dev/shm/trkinmem/
 mount -t squashfs -o loop,ro /dev/shm/trkinmem/trkramfs /linkedfs-ro/
 MountTrkRW
 exit 0
 else 
 mount /dev/$TRKHD /trk 
 echow "TRK 3.4 found on writable storage /dev/$TRKHD, attaching additional files (do not unplug this drive!)"
 mount -t squashfs -o loop,ro /trk/trk3/trkramfs /linkedfs-ro/
 MountTrkRW
 exit 0
 fi;
# End search for finding it on writable storage
fi;

echow "Seems we didn 't find anything yet. Trying CD-drives once more"
SearchCd
if [ -s /etc/trkcd ];then
MountTrkRW
fi;
echow "Seems we didn 't find the TRK medium"
color white
printf "Manually enter the device on which TRK can be found (e.g. 'sda1'): "
read TRKHD
export TRKHD
echo $TRKHD > /etc/trkhd
touch /var/run/runfromhd
color off
mount /dev/$TRKHD $TRKMOUNTDIR 
mount -t squashfs -o loop,ro $TRKMOUNTDIR/trk3/trkramfs /linkedfs-ro/ && MountTrkRW
# If the script didn 't exit here, there 's something wrong, drop to a shell and stop booting
echow "Something's wrong in startup, dropping to a shell, stop booting"
echow "'Use dmesg | more' to rerun your startup sequence and report the error on the forum"
echow "Also perform 'cat /proc/partitions' and 'cat /proc/sys/dev/cdrom/info'"
echow "As soon as you can mount trkramfs on the TRK medium to /linkedfs, you may type 'exit'"
echow "and the boot phase will continue"
bash
