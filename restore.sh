#!/bin/bash
#Restore files from a borg repo.

backupDir="/sbk/"
destLocation="/home/ian/Desktop/"
input=$(readlink -f "$1")

#Mount Code
#Check for issues.
if [[ ! -e "/dev/disk/by-uuid/f3ec445b-5ef2-48e4-bd7d-4661542e1dab" ]]
then
    echo "Access failure: No drive present."
    echo "[`date +%F`] Local access failure: No drive present." >> /home/ian/logs/backupfail
    exit
fi

if [[ -e "/tmp/rbkuplock" ]]
then
    echo "Access failure: Lockfile exists."
    echo "[`date +%F`] Local access failure: Lockfile exists." >> /home/ian/logs/backupfail
    exit
fi

#Mount the backup drive
touch "/tmp/rbkuplock"
echo ""<<!ENCRYPTION PASSWORD!>> | cryptsetup luksOpen /dev/disk/by-uuid/f3ec445b-5ef2-48e4-bd7d-4661542e1dab sbk
mount /dev/mapper/sbk /sbk/

if [[ "$input" =~ ^/home/ian/VirtualBox\ VMs ]]
then
    type="vm"
    prefix="sfs"
elif [[ "$input" =~ ^/bulk-files ]]
then
    type="bulk"
    prefix=""
    input="${input:1}"
elif [[ "$input" =~ ^/boot ]]
then
    type="boot"
    prefix=""
    input="${input:1}"
else
    type="main"
    prefix="sfs"
fi

borg list "${backupDir}${type}-backup" | grep "$type" | tac > ~/.restoreTemp
echo "Select a backup to restore from. Enter nothing to cancel."
cat ~/.restoreTemp | while read line; do i=$((i+1)); echo "$i) $line"; done
echo
read -p "Backup? " backup
if [[ "$((backup+1-1))" == "$backup" ]]
then
    backupName=$(cat ~/.restoreTemp | sed -n "${backup}p" | sed 's/ .*//g')
fi

if [[ "$backupName" != "" ]]
then
    cd "$destLocation"
    mkdir temp_delete
    cd temp_delete

    borg extract -v "${backupDir}${type}-backup::$backupName" "$prefix$input"
    cd ../

    mv "temp_delete/$prefix$input" "./"
    rm -r "temp_delete"
else
    echo "Abort."
fi

#Unmount code
umount /sbk
cryptsetup luksClose sbk
rm -f "/tmp/rbkuplock"
