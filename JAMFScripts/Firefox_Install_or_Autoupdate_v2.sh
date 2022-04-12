#!/bin/bash

#!/bin/zsh

:<<ABOUT_THIS_SCRIPT
-------------------------------------------------------------------------------
	Written by:William Smith
	Professional Services Engineer
	Jamf
	bill@talkingmoose.net
	https://gist.github.com/b99a43948c4784631e9ad60eb714c776
		
	Originally posted: April 16, 2020
	Last updated: January 17, 2021
	    Fixed unescaped quote causing "unexpected end of file" failure
	Purpose: Checks version of latest available version of Firefox online and
	compares with locally installed version. Downloads and installs if
	installed version is older or doesn't exist.
	
	Instructions:
	
	1. Set the optional sha256Checksum variable below for stronger
	security.
	
	2. If using Jamf Pro, add the script to the Scripts area and set parameter
	label 4 to "Checksum".
	
	3. Add the script to a policy. Optionally, enter the checksum in the
	Checksum parameter field.
	
	4. Enable the policy for Login with a frequency of Once Per Week or other
	periodic check.
	
	5. Enable inventory update, scope and deploy.
	Except where otherwise noted, this work is licensed under
	http://creativecommons.org/licenses/by/4.0/
	"Do not obey in advance."
	
-------------------------------------------------------------------------------
ABOUT_THIS_SCRIPT


# enter the SHA 256 checksum for the download file (DMG)
# download the package and run '/usr/bin/shasum -a 256 /path/to/file.dmg'
# this will change with each version
# leave blank to skip the checksum verification (less secure) or if using a $4 script parameter with Jamf Pro

#sha256Checksum="" # e.g. "67b1e8e036c575782b1c9188dd48fa94d9eabcb81947c8632fd4acac7b01644b"

#if [ "$4" != "" ] && [ "$sha256Checksum" = "" ]
#then
#	sha256Checksum=$4
#fi


# FILE_LOCATIONS --------------------------------------------------------------


# path to this script
currentDirectory=$( /usr/bin/dirname "$0" )

# name of this script
currentScript=$( /usr/bin/basename -s .bash "$0" )

# create log file in same directory as script
log="/Library/Logs/$currentScript.log"


# FUNCTIONS -------------------------------------------------------------------


function logcomment()	{
	/bin/date "+%Y-%m-%d %H:%M:%S	$1" >> "$log"
	echo "$1"
}


function logresult()	{
	if [ $? = 0 ] ; then
		/bin/date "+%Y-%m-%d %H:%M:%S	$1" >> "$log"
	else
		/bin/date "+%Y-%m-%d %H:%M:%S	$2" >> "$log"
	fi
}


# BEGIN SCRIPT ----------------------------------------------------------------


# specify the app bundle name
appName="Firefox.app"

# specify the app process name
processName="firefox"

# check whether application process is running
check=$( /usr/bin/pgrep "$processName")

if [ "$check" != "" ]; then
	
	# get currently logged in user
	currentUser=$( /usr/bin/stat -f "%Su" /dev/console )
	
	echo "Current user is $currentUser"
	
	# set dialog command
	theCommand="display dialog \"Mozilla Firefox app is currently running. Quit Firefox and try again.\" buttons {\"Stop\"} default button {\"Stop\"} with icon file posix file \"/Applications/Firefox.app/Contents/Resources/firefox.icns\""

	# display alert to end user
	/bin/launchctl asuser "$currentUser" sudo -iu "$currentUser" /usr/bin/osascript -e "$theCommand"
	
	echo "$processName is running. Aborting script"
	exit 0
fi

# define download url
downloadURL="https://download.mozilla.org/?product=firefox-latest-ssl&os=osx&lang=en-US" # regular release
# downloadURL="https://download.mozilla.org/?product=firefox-esr-latest&os=osx&lang=en-US" # ESR release

# online version check
# get the latest version of software available from website
latestVersion=$( /usr/bin/curl /usr/bin/curl https://www.mozilla.org/en-US/firefox/releases/ \
--silent | /usr/bin/grep '<html' | /usr/bin/awk -F\" '{ print $8 }'  )

# ESR online version check
#latestVersion=$( curl -sI "https://download.mozilla.org/?product=firefox-esr-latest&os=osx&lang=en-US" \
# --silent | /usr/bin/grep Location: | /usr/bin/awk -F '(%20|esr)' '{ print $3 }' )

logcomment "Latest version of $appName: $latestVersion"

# define app name and name of DMG after downloading
dmgFile="Firefox $latestVersion.dmg"


# Get the version number of the currently-installed app, if any.
if [ -e "/Applications/$appName" ]; then
	installedVersion=$( /usr/bin/defaults read "/Applications/$appName/Contents/Info.plist" CFBundleShortVersionString )
	echo "Installed version of $appName: $installedVersion"
	if [ ${latestVersion} = ${installedVersion} ]; then
		logcomment "$appName is current. Exiting."
		exit 0
	fi
else
	logcomment "$appName is either not installed or not up to date."
fi


# create temporary working directory
workDirectory=$( /usr/bin/basename "$0" )
tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )
echo "Creating working directory '$tempDirectory'"

# change directory to temporary working directory
echo "Changing directory to working directory '$tempDirectory'"
cd "$tempDirectory"

# downloading software
logcomment "Downloading $dmgFile..."
/usr/bin/curl "$downloadURL" \
--silent \
--location \
--output "$dmgFile"
logresult "Downloaded DMG." "Failed to download DMG."

# checksum the download
downloadChecksum=$( /usr/bin/shasum -a 256 "$tempDirectory/$dmgFile" | /usr/bin/awk '{ print $1 }' )
echo "Checksum for downloaded file: $downloadChecksum"

# install the download if checksum validates
if [ "$sha256Checksum" = "$downloadChecksum" ] || [ "$sha256Checksum" = "" ]; then
	echo "Checksum verified. Installing software..."
	
	# mounting DMG
	logcomment "Mounting $dmgFile..."
	appVolume=$( /usr/bin/hdiutil attach -nobrowse "$tempDirectory/$dmgFile" | /usr/bin/grep /Volumes | /usr/bin/sed -e 's/^.*\/Volumes\///g' )
	logresult "Mounted $dmgFile." "Failed to mount $dmgFile."
	
	# install software
	logcomment "Installing software..."
	/usr/bin/ditto -rsrc "/Volumes/$appVolume/$appName" "/Applications/$appName"
	logresult "Installed software." "Failed to install software."

	# unmount DMG
	logcomment "Unmounting $dmgFile..."
	/sbin/umount -f "/Volumes/$appVolume" # forcibly unmount
	logresult "Unmounting $dmgFile." "Failed to unmount $dmgFile."

else
	echo "Checksum failed. Recalculate the SHA 256 checksum and try again. Or download may not be valid."
	exit 1
fi

# delete DMG
logcomment "Deleting DMG..."
/bin/rm -R "$tempDirectory"
logresult "Deleted DMG." "Failed to delete DMG."

# END SCRIPT ----------------------------------------------------------------

exit 0