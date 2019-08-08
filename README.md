Backup Script

This script backups up the main SSD, my hard drive, bootloader, and VMs at different intervals. The VMs and SSD are backed up using an LVM snapshot. It will show an error message and attempt to send a text message if something breaks. (The text messages have been broken for a while.) Put in Cron for every 4 hours.


Backup Drive Mounter

Use this to mount the backup drive and open a file manager for looking at the repo and copying regular files to the drive for some reason.


Backup Volume Mounter

This allows you to mount an actual backup and open a file manager to that backup so you can inspect and copy files from a backup. It will ask you to select the backup chain type and actual backup to mount.


File Restore Tool

Use this toll to restore files directly to the desktop interactively. This is great for when you make a mistake and are in a hurry.

