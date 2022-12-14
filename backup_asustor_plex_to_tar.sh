#!/usr/bin/env bash
# shellcheck disable=SC2317,SC2181
#--------------------------------------------------------------------------
# Backup Asustor NAS Plex Database to tgz file in Backup folder.
# v5.0  20-Nov-2022  007revad
#
#                    ***** MUST BE RUN AS ROOT *****
# 
# Run as ROOT from WinSCP console, Putty or scheduled task:
# bash /volume1/scripts/backup_asustor_plex_to_tar.sh
#	Change /volume1/scripts/ to path where this script is located
#
# To do a test run on just Plex's profiles folder run:
# bash /volume1/scripts/backup_asustor_plex_to_tar.sh test
#
# Gist on Github: https://gist.github.com/007revad
# Script verified at https://www.shellcheck.net/
#--------------------------------------------------------------------------
# Optional:
# For separate log and error log for tar command the Asustor needs bash installed
# By default redirection does not work because ADM does not include bash
# Causes error:
# line xx: /dev/fd/62: No such file or directory
#
# Install Entware from App Central then run the following commands via SSH
# opkg update && opkg upgrade
# opkg install bash
#--------------------------------------------------------------------------


# Set location to save tgz file to
Backup_Directory="/volume1/Backups/Plex_Backup"

# The script gets the brand, model and hostname from the NAS to use logs and backup name.
# Set Name= to "brand", "model", "hostname" or some nickname.
# If Name= is blank the Asustor's hostname will be used.
Name="brand"


#--------------------------------------------------------------------------
#               Nothing below here should need changing
#--------------------------------------------------------------------------

# Set date and time variables

# Timer variable to log time taken to backup PMS
start="${SECONDS}"

# Get Start Time and Date
Started=$( date )

# Get Today's date for filename
Now=$( date '+%Y%m%d')
# Get Today's date and time for filename in case filename exists
NowLong=$( date '+%Y%m%d-%H%M')


#--------------------------------------------------------------------------
# Set NAS name (used in backup and log filenames)

case "$Name" in
	brand)
		# Get NAS Brand
		if [[ -f /etc/nas.conf ]]; then
			Nas="$(awk '/^Vendor\s/{print $3}' /etc/nas.conf)"
		fi
		;;
	model)
		# Get Asustor model
		if [[ -f /etc/nas.conf ]]; then
			Nas="$(awk '/^Model\s/{print $3}' /etc/nas.conf)"
		fi
		;;
	hostname|"")
		# Get Hostname
		Nas=$( hostname )
		;;
	*)
		# Set Nas to nickname
		Nas="$Name"
		;;
esac


#--------------------------------------------------------------------------
# Set temporary log filenames (we get the Plex version later)

# Set backup filename
Backup_Name="${Nas}"_"${Now}"_Plex_"${Version}"_Backup

# If file exists already include time in name
BackupPN="$Backup_Directory/$Backup_Name"
if [[ -f $BackupPN.tgz ]] || [[ -f $BackupPN.log ]] || [[ -f "$BackupPN"_ERROR.log ]]; then
	Backup_Name="${Nas}"_"${NowLong}"_Plex_"${Version}"_Backup
fi

# Set log filename
Log_File="${Backup_Directory}"/"${Backup_Name}".log

# Set error log filename
Err_Log_File="${Backup_Directory}"/"${Backup_Name}"_ERROR.log


#--------------------------------------------------------------------------
# Create temp error log

# Asustor mktemp only accepts max 6 Xs

# Create temp directory for temp error log
Tmp_Dir=$(mktemp -d -t plex_to_tar-XXXXXX)

# Create temp error log
Tmp_Err_Log_File=$(mktemp "${Tmp_Dir}"/errorlog-XXXXXX)


#--------------------------------------------------------------------------
# Create trap and cleanup function

# Trap script terminating errors so we can cleanup
trap cleanup 1 2 3 6 15 EXIT

# Tmp logs cleanup function
cleanup() {
	arg1=$?
	# Move tmp_error_log to error log if tmp_error_log is not empty
	if [[ -s $Tmp_Err_Log_File ]] && [[ -d $Backup_Directory ]]; then
		mv "${Tmp_Err_Log_File}" "${Err_Log_File}"
		if [[ $? -gt "0" ]]; then
			echo "WARN: Failed moving ${Tmp_Err_Log_File} to ${Err_Log_File}" |& tee -a "${Err_Log_File}"
		fi
	fi
	# Delete our tmp directory
	if [[ -d $Tmp_Dir ]]; then
		rm -rf "${Tmp_Dir}"
		if [[ $? -gt "0" ]]; then
			echo "WARN: Failed deleting ${Tmp_Dir}" |& tee -a "${Err_Log_File}"
		fi
	fi

	# Log and notify of success or errors
	if [[ -f $Err_Log_File ]]; then
		# Log and notify backup had errors
		if [[ ! -f $Log_File ]]; then
			# Add script name to top of log file
			basename -- "$0" |& tee -a "${Log_File}"
fi
#		echo " " |& tee -a "${Log_File}"
		echo "" |& tee -a "${Log_File}"
		echo "WARN: Plex backup had errors! See error log:" |& tee -a "${Log_File}"
		#echo "${Err_Log_File}" |& tee -a "${Log_File}"
		# Remove /volume#/ from error log path
		Err_Log_Short=$(printf %s "${Err_Log_File}"| sed "s/\/volume.*\///g")
		echo "${Err_Log_Short}" |& tee -a "${Log_File}"

		# Add entry to Asustor log
		if [[ $Brand == 'ASUSTOR' ]]; then
			if [[ $Version ]]; then
				syslog --log 0 --level 0 --user "$( whoami )" --event "Plex ${Version} backup had errors. See ERROR.log"
			else
				syslog --log 0 --level 0 --user "$( whoami )" --event "Plex backup had errors. See ERROR.log"
			fi
		fi
	else
		# Log and notify of backup success
#		echo " " |& tee -a "${Log_File}"
		echo "" |& tee -a "${Log_File}"
		echo "Plex backup completed successfully" |& tee -a "${Log_File}"

		# Add entry to Asustor log
		if [[ $Version ]]; then
			syslog --log 0 --level 0 --user "$( whoami )" --event "Plex ${Version} backup successful."
		else
			syslog --log 0 --level 0 --user "$( whoami )" --event "Plex backup successful."
		fi
	fi
	exit "${arg1}"
}


#--------------------------------------------------------------------------
# Check that script is running as root

if [[ $( whoami ) != "root" ]]; then
	if [[ -d $Backup_Directory ]]; then
		echo ERROR: This script must be run as root! |& tee -a "${Tmp_Err_Log_File}"
		echo ERROR: "$( whoami )" is not root. Aborting. |& tee -a "${Tmp_Err_Log_File}"
	else
		# Can't log error because $Backup_Directory does not exist
		echo
		echo ERROR: This script must be run as root!
		echo ERROR: "$( whoami )" is not root. Aborting.
		echo
	fi
	# Add entry to Asustor system log
	if [[ $Brand == 'ASUSTOR' ]]; then
		syslog --log 0 --level 1 --user "$( whoami )" --event "Plex backup failed. Needs to run as root."
	fi
	# Abort script because it isn't being run by root
	exit 255
fi


#--------------------------------------------------------------------------
# Check script is running on an Asustor NAS

if [[ -f /etc/nas.conf ]]; then Brand="$(awk '/^Vendor\s/{print $3}' /etc/nas.conf)"; fi
# Returns: ASUSTOR

if [[ $Brand != 'ASUSTOR' ]]; then
	if [[ -d $Backup_Directory ]]; then
		echo Checking script is running on a Asustor NAS |& tee -a "${Tmp_Err_Log_File}"
		echo ERROR: "$( hostname )" is not a Asustor! Aborting. |& tee -a "${Tmp_Err_Log_File}"
	else
		# Can't log error because $Backup_Directory does not exist
		echo
		echo Checking script is running on a Asustor NAS
		echo ERROR: "$( hostname )" is not a Asustor! Aborting.
		echo
	fi
#	# Add entry to Asustor system log
#	# Can't Add entry to Asustor system log because script not running on an Asustor
#	syslog --log 0 --level 1 --user "$( whoami )" --event "Plex backup failed. See the error log."
	# Abort script because it's being run on the wrong NAS brand
	exit 255
fi


#--------------------------------------------------------------------------
# Find Plex Media Server location

# Get the Plex Media Server data location
# Asustor always installs apps on volume1 aka volmain
Plex_Data_Path=/volume1/Plex/Library
# /volume1/Plex/Library

# Check Plex Media Server data path exists
if [[ ! -d $Plex_Data_Path ]]; then
	echo Plex Media Server data path invalid! Aborting. |& tee -a "${Tmp_Err_Log_File}"
	echo "${Plex_Data_Path}" |& tee -a "${Tmp_Err_Log_File}"
	# Add entry to Asustor system log
	syslog --log 0 --level 1 --user "$( whoami )" --event "Plex backup failed. Plex data path invalid."
	# Abort script because Plex data path invalid
	exit 255
fi


#--------------------------------------------------------------------------
# Get Plex Media Server version

Version="$(/volume1/.@plugins/AppCentral/plexmediaserver/Plex\ Media\ Server --version)"
# Returns v1.29.2.6364-6d72b0cf6
# Plex version without hex string
Version=$(printf %s "${Version:1}"| cut -d "-" -f1)
# Returns 1.29.2.6364


#--------------------------------------------------------------------------
# Re-assign log names to include Plex version

# Backup filename
Backup_Name="${Nas}"_"${Now}"_Plex_"${Version}"_Backup

# If file exists already include time in name
BackupPN="$Backup_Directory/$Backup_Name"
if [[ -f $BackupPN.tgz ]] || [[ -f $BackupPN.log ]] || [[ -f "$BackupPN"_ERROR.log ]]; then
	Backup_Name="${Nas}"_"${NowLong}"_Plex_"${Version}"_Backup
fi

# Log file filename
Log_File="${Backup_Directory}"/"${Backup_Name}".log

# Error log filename
Err_Log_File="${Backup_Directory}"/"${Backup_Name}"_ERROR.log


#--------------------------------------------------------------------------
# Start logging

# Log NAS brand, model, DSM version and hostname
Model="$(awk '/^Model\s/{print $3}' /etc/nas.conf)"
ADMversion="$(awk '/^Version\s/{print $3}' /etc/nas.conf)"
echo "${Brand}" "${Model}" ADM "${ADMversion}" |& tee -a "${Log_File}"
echo "Hostname: $( hostname )" |& tee -a "${Log_File}"

# Log Plex version
echo Plex version: "${Version}" |& tee -a "${Log_File}"


#--------------------------------------------------------------------------
# Check if backup directory exists

if [[ ! -d $Backup_Directory ]]; then
	#echo "ERROR: Backup directory not found! Aborting backup." |& tee -a "${Log_File}" "${Err_Log_File}"
	echo "ERROR: Backup directory not found! Aborting backup." |& tee -a "${Log_File}" "${Tmp_Err_Log_File}"
	# Add entry to Asustor system log
	syslog --log 0 --level 1 --user "$( whoami )" --event "Plex backup failed. Backup directory not found."
	# Abort script because backup directory not found
	exit 255
fi


#--------------------------------------------------------------------------
# Stop Plex Media Server

echo "Stopping Plex..." |& tee -a "${Log_File}"
Result=$(/usr/local/AppCentral/plexmediaserver/CONTROL/start-stop.sh stop)
wait

if [ "$Result" != "${Result#stopped process in pidfile}" ]; then
	echo "Plex Media Server has stopped." |& tee -a "$Log_File"
elif [ "$Result" != "${Result#none killed}" ]; then
	echo "Plex Media Server wasn't running." |& tee -a "$Log_File"
else
	echo "$Result" |& tee -a "$Log_File"
fi
# Give sockets a moment to close
sleep 5

# Kill any residual Plex processes (plug-ins, tuner service and EAE etc)
pgrep [Pp]lex | xargs kill -9
sleep 5

# Check if all Plex processes have stopped
echo Checking status of Plex processes... |& tee -a "${Log_File}"
Response=$(pgrep -l plex)
# Check if plexmediaserver was found in $Response
if [[ -n $Response ]]; then
	echo "ERROR: Some Plex processes still running! Aborting backup." |& tee -a "${Log_File}" "${Tmp_Err_Log_File}"
	echo "${Response}" |& tee -a "${Log_File}" "${Tmp_Err_Log_File}"
	# Kill any residual Plex processes (plug-ins, tuner service and EAE etc)
	pgrep [Pp]lex | xargs kill -11
	sleep 5
	# Start Plex to ensure it's running
	/usr/local/AppCentral/plexmediaserver/CONTROL/start-stop.sh start
	# Add entry to Asustor system log
	syslog --log 0 --level 1 --user "$( whoami )" --event "Plex backup failed. Plex didn't shut down."
	# Abort script because Plex didn't shut down fully
	exit 255
else
	echo "All Plex processes have stopped." |& tee -a "${Log_File}"
fi


#----------------------------------------------------------
# Backup Plex Media Server

echo "=======================================" |& tee -a "${Log_File}"
echo "Backing up Plex Media Server data files:" |& tee -a "${Log_File}"

# Redirecting stdout and stderr to separate Log and Error Log
# causes an error on Asustor NAS unless bash is installed.
# Check if script is using bash and not busybox (ash, sh)
GnuBash=$(/proc/self/exe --version 2>/dev/null | grep "GNU bash" | cut -d "," -f1)

Exclude_File="$( dirname -- "$0"; )/plex_backup_exclude.txt"

# Check for test or error arguments
if [[ -n "$1" ]] && [[ "$1" =~ [Ee][Rr][Rr][Oo][Rr]$ ]]; then
	# Trigger an error to test error logging
	Test="Plex Media Server/Profiles/ERROR/"
	echo "Running small error test backup of Profiles folder" |& tee -a "${Log_File}"
elif [[ -n "$1" ]] && [[ "$1" =~ [Tt][Ee][Ss][Tt]$ ]]; then
	# Test on small Profiles folder only
	Test="Plex Media Server/Profiles/"
	echo "Running small test backup of Profiles folder" |& tee -a "${Log_File}"
fi

# Check if exclude file exists
# Must come after "Check for test or error arguments"
if [[ -f $Exclude_File ]]; then
	# Unset arguments
	while [[ $1 ]]
	do
		shift
	done
	# Set -X excludefile arguments for tar
	set -- "$@" "-X"
	set -- "$@" "${Exclude_File}"
else
	echo "INFO: No exclude file found." |& tee -a "${Log_File}"
fi

# Run tar backup command
if [[ -n "$Test" ]]; then
	# Running backup test or error test
	if [[ $GnuBash == "GNU bash" ]]; then
		# bash is installed so we can log tar errors to error log
		tar -cvpzf "${Backup_Directory}"/"${Backup_Name}".tgz "$@" -C "${Plex_Data_Path}" "${Test}" > >(tee -a "${Log_File}") 2> >(tee -a "${Log_File}" "${Tmp_Err_Log_File}" >&2)
	else
		# bash isn't installed so tar errors will be included in log file
		tar -cvpzf "${Backup_Directory}"/"${Backup_Name}".tgz "$@" -C "${Plex_Data_Path}" "${Test}" |& tee -a "${Log_File}"
	fi
else
	# Backup to tgz with PMS version and date in file name, send all output to shell and log, plus errors to error.log
	# Using -C to change directory to "/volume#/Plex/Library/Application Support" to not backup absolute path and avoid "tar: Removing leading /" error
	if [[ $GnuBash == "GNU bash" ]]; then
		# bash is installed so we can log tar errors to error log
		tar -cvpzf "${Backup_Directory}"/"${Backup_Name}".tgz "$@" -C "${Plex_Data_Path}" "Plex Media Server/" > >(tee -a "${Log_File}") 2> >(tee -a "${Log_File}" "${Tmp_Err_Log_File}" >&2)
	else
		# bash isn't installed so tar errors will be included in log file
		tar -cvpzf "${Backup_Directory}"/"${Backup_Name}".tgz "$@" -C "${Plex_Data_Path}" "Plex Media Server/" |& tee -a "${Log_File}"
	fi
fi


#--------------------------------------------------------------------------
# Start Plex Media Server

echo "=======================================" |& tee -a "${Log_File}"
echo Starting Plex... |& tee -a "${Log_File}"

/usr/local/AppCentral/plexmediaserver/CONTROL/start-stop.sh start
wait


#--------------------------------------------------------------------------
# Append the time taken to stdout and log file

# End Time and Date:
Finished=$( date )

# bash timer variable to log time taken to backup PMS:
end="${SECONDS}"

# Elapsed time in seconds:
Runtime=$(( end - start ))

# Append start and end date/time and runtime
#echo " " |& tee -a "${Log_File}"
echo "" |& tee -a "${Log_File}"
echo "Backup Started: " "${Started}" |& tee -a "${Log_File}"
echo "Backup Finished:" "${Finished}" |& tee -a "${Log_File}"
# Append days, hours, minutes and seconds from $Runtime
printf "Backup Duration: " |& tee -a "${Log_File}"
printf '%dd:%02dh:%02dm:%02ds\n' \
$((Runtime/86400)) $((Runtime%86400/3600)) $((Runtime%3600/60)) \ $((Runtime%60)) |& tee -a "${Log_File}"


#--------------------------------------------------------------------------
# Add Plex backup status to system log

#if [[ $Version ]]; then
#	syslog --log 0 --level 0 --user "$( whoami )" --event "Plex ${Version} backup successful."
#else
#	syslog --log 0 --level 0 --user "$( whoami )" --event "Plex backup successful."
#fi


#--------------------------------------------------------------------------
# Trigger cleanup function
exit 0

