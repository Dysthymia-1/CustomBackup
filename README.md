# Custom backup script

This script was originally created for my son, but has been adapted to be a custom backup script anyone can use. It only requires that the end user first populate the $Data array variable in it with the paths (in quotes) that they want to be backed up.

It handles testing those paths to make sure they're reachable, quantifying the amount of data to be backed up, asks for a backup location at runtime and ensures enough free space is available there. 

Backups can be carried out with robocopy or they can be compressed using 7-Zip if it's detected, with user-configurable compression. Backups are timestamped and logged. 
