#!/bin/bash
#Mount a borg repo.
backupDir="/sbk/"
destLocation="/mnt"

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
echo "<<!ENCRYPTION PASSWORD!>>" | cryptsetup luksOpen /dev/disk/by-uuid/f3ec445b-5ef2-48e4-bd7d-4661542e1dab sbk
mount /dev/mapper/sbk /sbk/

echo "Select backup type. Enter nothing to show all."
echo -e 'main\nbulk\nvm\nboot' | while read line; do i=$((i+1)); echo "$i) $line"; done
echo
read -p "Type? " typeNum
type=$(echo -e 'main\nbulk\nvm\nboot' | sed -n "${typeNum}p" | sed 's/ .*//g')
if [[ "$type" == "" ]]
then
    type=".*"
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
    borg mount "${backupDir}${type}-backup::$backupName" "$destLocation"
else
    echo "Abort."
fi

pcmanfm "$destLocation"
fusermount -u "$destLocation"

#Unmount code
umount /sbk
cryptsetup luksClose sbk
rm -f "/tmp/rbkuplock"
