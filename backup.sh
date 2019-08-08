#!/bin/bash
startTime=$(date +%s)
hour="$(date +%H)"
set -o pipefail

function sendError {
    echo "Backup failure: $1"
    echo "[`date +%F`] Local backup failure: $1" >> /home/ian/logs/backupfail
    curl https://textbelt.com/text -d number=<<!PHONE NUMBER!>> -d "message=[`date +%F`] Local backup failure: $1"
    export DISPLAY=:0
    zenity --error --title "System Notification" --text "[`date +%F`] ian-thinkpad: $1" &
}

#Check for issues.
if [[ ! -e "/dev/disk/by-uuid/f3ec445b-5ef2-48e4-bd7d-4661542e1dab" ]]
then
    sendError "No drive present."
    exit
fi

#if [[ -e "/tmp/rbkuplock" ]]
#then
#    sendError "Lockfile exists."
#    exit
#fi

#Wait for the lock to go away.
if [[ -e "/tmp/rbkuplock" ]]
then
    if [[ -e "/tmp/rbkupw" ]]
    then
        sendError "Only one local backup may wait for lock."
        exit
    else
        touch "/tmp/rbkupw"
        while [[ -e "/tmp/rbkuplock" ]]
        do
            sleep 30
            echo "Waiting for unlock..."
        done
        /bin/rm -f "/tmp/rbkupw"
    fi
fi

#Create Lock
touch "/tmp/rbkuplock"
currentDate=$(date +%FT%R)

#Mount the backup drive
echo "<<!ENCRYPTION PASSWORD!>>" | /sbin/cryptsetup luksOpen /dev/disk/by-uuid/f3ec445b-5ef2-48e4-bd7d-4661542e1dab sbk
mount /dev/mapper/sbk /sbk/

#Ensure the backup is actually there.
if [[ ! -e "/sbk/main-backup" ]]
then
    sendError "No folder present."
    exit
fi

#Create an LVM snapshot
/sbin/pvchange -xy /dev/mapper/sdb5_crypt
sync
/sbin/lvcreate --size 10g --snapshot --name sfs /dev/ian-thinkpad-vg/root
mount -r /dev/ian-thinkpad-vg/sfs /sfs
if [[ ! -e "/sfs/home" ]]
then
    sendError "No snapshot present."
    umount /sfs
    /sbin/lvremove -f /dev/ian-thinkpad-vg/sfs
    umount /sbk
    /sbin/cryptsetup luksClose sbk
    /bin/rm -f "/tmp/rbkuplock"
    exit
fi

#Prepare the cache.
mount -t tmpfs -o size=10g tmpfs /root/.cache/borg
rsync -a /root/.cache/borg-main/ /root/.cache/borg/

#Perform the backup.
/home/ian/bookmarks/scripts/soft-backup.sh
borg prune /sbk/main-backup -vs -p main --keep-within=2d -d 10 -w 4 -m 12 -y 10 2>&1 | tee /home/ian/logs/backupprune

#Check for issues.
if [[ "$?" != "0" ]]
then
    sendError "Prune errors were reported."
fi

borg create -vs --compression zlib,1 \
--exclude /sfs/sbk/ \
--exclude /sfs/media/ \
--exclude /sfs/mnt/ \
--exclude /sfs/tmp/ \
--exclude /sfs/proc/ \
--exclude /sfs/home/ian/.cache/ \
--exclude /sfs/root/.cache/ \
--exclude /sfs/run/ \
--exclude /sfs/var/cache/ \
--exclude /sfs/var/tmp/ \
--exclude /sfs/tmp/ \
--exclude /sfs/dev/ \
--exclude /sfs/sys/ \
--exclude /sfs/home/ian/VirtualBox\ VMs/ \
--exclude /sfs/bulk-files/ \
"/sbk/main-backup::main-$currentDate" /sfs/ 2>&1 | tee /home/ian/logs/mainbackup

if [[ "$?" != "0" ]]
then
    sendError "Main backup errors."
fi

#Change the cache.
rsync -a --delete /root/.cache/borg/ /root/.cache/borg-main/
umount /root/.cache/borg
mount -t tmpfs -o size=10g tmpfs /root/.cache/borg
rsync -a /root/.cache/borg-boot/ /root/.cache/borg/

borg prune /sbk/boot-backup -vs -p boot --keep-within=2d -d 10 -w 4 -m 12 -y 10 2>&1 | tee -a /home/ian/logs/backupprune

#Check for issues.
if [[ "$?" != "0" ]]
then
    sendError "Prune errors were reported."
fi

borg create -vs --compression zlib,1 "/sbk/boot-backup::boot-$currentDate" /boot/ 2>&1 | tee /home/ian/logs/bootbackup

if [[ "$?" != "0" ]]
then
    sendError "Boot backup errors."
fi

#Unmount the cache.
rsync -a --delete /root/.cache/borg/ /root/.cache/borg-boot/
umount /root/.cache/borg

if [[ "$hour" == "04" ]] || [[ "$1" == "vmforce" ]]
then
    if [[ "$(date +%w)" == "1" ]] || [[ "$1" == "vmforce" ]]
    then
        #Prepare the cache.
        mount -t tmpfs -o size=10g tmpfs /root/.cache/borg
        rsync -a /root/.cache/borg-vm/ /root/.cache/borg/

        borg prune /sbk/vm-backup -vs -p vm -w 4 -m 12 -y 10 2>&1 | tee -a /home/ian/logs/backupprune

        #Check for issues.
        if [[ "$?" != "0" ]]
        then
            sendError "Prune errors were reported."
        fi

        borg create -vs --compression zlib,1 "/sbk/vm-backup::vm-$currentDate" '/sfs/home/ian/VirtualBox VMs/' 2>&1 | tee /home/ian/logs/vmbackup

        #Check for issues.
        if [[ "$?" != "0" ]]
        then
            sendError "VM backup errors"
        fi

        #Unmount the cache.
        rsync -a --delete /root/.cache/borg/ /root/.cache/borg-vm/
        umount /root/.cache/borg
    fi

fi

#Delete the snapshot.
umount /sfs
/sbin/lvremove -f /dev/ian-thinkpad-vg/sfs

if [[ "$hour" == "04" ]] || [[ "$1" == "bulkforce" ]] #Run the backup at 04 only.
then
    #Prepare the cache.
    mount -t tmpfs -o size=10g tmpfs /root/.cache/borg
    rsync -a /root/.cache/borg-bulk/ /root/.cache/borg/

    borg prune /sbk/bulk-backup -vs -p bulk -d 10 -w 4 -m 12 -y 10 2>&1 | tee -a /home/ian/logs/backupprune

    #Check for issues.
    if [[ "$?" != "0" ]]
    then
        sendError "Prune errors were reported."
    fi

    borg create -vs --compression zlib,1 "/sbk/bulk-backup::bulk-$currentDate" /bulk-files/ 2>&1 | tee /home/ian/logs/bulkbackup

    if [[ "$?" != "0" ]]
    then
        sendError "Bulk backup errors."
    fi

    #Unmount the cache.
    rsync -a --delete /root/.cache/borg/ /root/.cache/borg-bulk/
    umount /root/.cache/borg
fi

if [[ "`df | grep /dev/mapper/sbk | awk '{ print $4 }'`" -lt "104857600" ]]
then
    sendError "Less than 100GB on drive."
fi

#Make sure the drive is set for sleep.
if [[ -e "/dev/disk/by-uuid/f3ec445b-5ef2-48e4-bd7d-4661542e1dab" ]]
then
    hdparm -S 60 /dev/disk/by-uuid/f3ec445b-5ef2-48e4-bd7d-4661542e1dab
fi

#Unmount the backup drive.
umount /sbk
/sbin/cryptsetup luksClose sbk
/bin/rm -f "/tmp/rbkuplock"
endTime=$(date +%s)
echo "Backup took $(((endTime-startTime)/3600)):$((((endTime-startTime)%3600)/60))." | tee -a /home/ian/logs/mainbackup
