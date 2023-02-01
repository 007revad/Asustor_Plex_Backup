# Asustor Plex Backup

<a href="https://github.com/007revad/Asustor_Plex_Backup/releases"><img src="https://img.shields.io/github/release/007revad/Asustor_Plex_Backup.svg"></a>
<a href="https://hits.seeyoufarm.com"><img src="https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2F007revad%2FAsustor_Plex_Backup&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=hits&edge_flat=false"/></a>

### Description

This is a bash script to backup an Asustor's Plex Media Server settings and database, and log the results.

The script was written to work on ADM 4.x though it may work on older versions.

#### What the script does:

-   Gets your Asustor's hostname and model (for use in the backup filename and log name).
-   Checks that the script is running with the required privileges.
-   Checks it is running on a Asustor NAS.
-   Gets Plex Media Server's version (for the backup filename and log).
-   Checks the volume and share name where Plex Media Server's database is located.
-   Checks that your specified backup location exists.
-   Stops Plex Media Server, then checks Plex actually stopped.
-   Backs up Plex Media Server to a tgz file (**excluding the folders listed in plex_backup_exclude.txt**).
-   Starts Plex Media Server.
-   Adds an entry to the Asustor's system log stating if the backup succeded or failed (can be disabled in config file).

#### It also saves a log in the same location as the backup file, including:

-   Logging the start and end time plus how long the backup took.
-   Logging every file that was backed up (can be disabled in config file).
-   Logging any errors to a separate error log file to make it easy for you to see if there were errors.

The Asustor's hostname, date, and Plex Media Server version are included in the backup's filename in case you need to roll Plex back to an older version or you save backups from more than one Plex Servers.

**Example of the backup's auto-generated filenames:** 
-   ASUSTOR_20221025_Plex_1.29.0.6244_Backup.tgz
-   ASUSTOR_20221025_Plex_1.29.0.6244_Backup.log
-   ASUSTOR_20221025_Plex_1.29.0.6244_Backup_ERROR.log (**only if there was an error**)

If you run multiple backups on the same day the time will be included in the filename.

**Example of the backup's auto-generated filenames:** 
-   ASUSTOR_20221025_1920_Plex_1.29.0.6244_Backup.tgz
-   ASUSTOR_20221025_1920_Plex_1.29.0.6244_Backup.log

### Settings

You need to set **backupDirectory=** near the top of the script (below the header). Set it to the location where you want the backup saved to. 

```YAML
backupDirectory="/volume1/Backups/Plex_Backups"
```

The script gets the brand, model and hostname from the NAS to use logs and backup name.
Set Name= to "brand", "model", "hostname" or some nickname. If Name= is blank the Synology's hostname will be used.

The LogAll setting enables, or disables, logging every file that gets backed up. Set LogAll= to "yes" or "no". Blank is the same as no.

The SysLog setting allows adding a success or failed entry to ADM's system log. Set SysLog= to "yes" or "no". Blank is the same as no.

```YAML
Name="brand"
LogAll="no"
SysLog="yes"
```

### Requirements

Make sure that backup_asustor_plex.config and plex_backup_exclude.txt are in the same folder as backup_asustor_plex_to_tar.sh

**Note:** Due to some of the commands used **this script needs to be** run by a user in sudo, sudoers or wheel group, or as root

**OPTIONAL:** 
Because ADM uses ash (in BusyBbox) instead of bash you will need to install bash.

**To install bash** first **install Entware from App Central** then run the following commands via SSH, PuTTY (or Shell In A Box from App Central).
```YAML
    opkg update && opkg upgrade
    opkg install bash
```

### Running the script

Run the script by a user in sudo, sudoers or wheel group.

```YAML
sudo "/volume1/scripts/Backup_Plex_on_Asustor.sh test"
```

### Testing the script

If you run the script with the **test** argument it will only backup Plex's Logs folder.

```YAML
sudo "/volume1/scripts/Backup_Plex_on_Asustor.sh test"
```

If you run the script with the **error** argument it will only backup Plex's Logs folder and cause an error so you can test the error logging.

```YAML
sudo "/volume1/scripts/Backup_Plex_on_Asustor.sh error"
```
