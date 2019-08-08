#!/bin/bash

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

#Perform the access.
pcmanfm /sbk

#Check for issues.
if [[ "`df | grep /dev/mapper/sbk | awk '{ print $4 }'`" -lt "104857600" ]]
then
    echo "Backup warning: Less than 100GB on drive."
    echo "[`date +%F`] Local backup warning: Less than 100GB on drive." >> /home/ian/logs/backupfail
    curl https://textbelt.com/text -d number=<<!PHONE NUMBER!>> -d "message=[`date +%F`] Local backup warning: Less than 100GB on drive."
fi

#Unmount the backup drive.
umount /sbk
cryptsetup luksClose sbk
rm -f "/tmp/rbkuplock"
