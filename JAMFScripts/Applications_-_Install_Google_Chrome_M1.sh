#!/bin/sh
#####################################################################################################
#
# ABOUT THIS PROGRAM
#
# NAME
#	GoogleChromeInstall.sh -- Installs the latest Google Chrome version on Apple M1 Silicon
#
# SYNOPSIS
#	sudo Applications_-_Install_Google_Chrome_M1.sh
#       depricated - sudo GoogleChromeInstall_M1.sh
#
#	Author: Andrew Ellis
#	Date: 9/1/2021
#
####################################################################################################
# Script to download and install Google Chrome.
# Only works on Intel systems.

dmgfile="googlechrome.dmg"
volname="Google Chrome"
logfile="/Library/Logs/GoogleChromeInstall_M1_Script.log"

url='https://dl.google.com/chrome/mac/universal/stable/CHFA/googlechrome.dmg'

# Are we running on Intel?
if [ '`/usr/bin/uname -p`'="i386" -o '`/usr/bin/uname -p`'="arm64" ]; then
		/bin/echo "-- START" >> ${logfile}
		/bin/echo "`date`: Downloading latest version." >> ${logfile}
		/usr/bin/curl -s -o /tmp/${dmgfile} ${url}
		/bin/echo "`date`: Mounting installer disk image." >> ${logfile}
		/usr/bin/hdiutil attach /tmp/${dmgfile} -nobrowse -quiet
		/bin/echo "`date`: Installing..." >> ${logfile}
		ditto -rsrc "/Volumes/${volname}/Google Chrome.app" "/Applications/Google Chrome.app"
		/bin/sleep 10
		/bin/echo "`date`: Unmounting installer disk image." >> ${logfile}
		/usr/bin/hdiutil detach $(/bin/df | /usr/bin/grep "${volname}" | awk '{print $1}') -quiet
		/bin/sleep 10
		/bin/echo "`date`: Deleting disk image." >> ${logfile}
		/bin/rm /tmp/"${dmgfile}"
        /bin/echo "END --" >> ${logfile}
        /bin/echo "" >> ${logfile}
else
	/bin/echo "`date`: ERROR: This script is for Intel Macs only." >> ${logfile}
fi

exit 0