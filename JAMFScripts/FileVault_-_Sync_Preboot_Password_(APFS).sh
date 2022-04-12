#!/bin/sh

################################################################################################
#
# Name:  FileVault_Password_Sync_Fix.sh
# Creation Date:  November 28, 2018
# Author:  Richard Thomson
#
################################################################################################
#
# Purpose
# 
# The purpose of this script is to correct a potential password mismatch or synchronization 
# issue that can result from changing a network password for a mobile account and attempting 
# to log in to a FileVault encrypted system that the user had previously logged in to before.
#
# Example:  On a FileVault encrypted system, the user changes their network (AD) password 
# either on the Mac itself or via another IT supported method. When attempting to log in to 
# the system, the user must enter the old password or the old password in addition to the 
# new (later prompted at login window).
#
# This script will prompt the user for their old (out-of-date) password and their current 
# network (AD) password. The passphrase for their device will be updated to sync the user's 
# password to the Preboot environment.
#
################################################################################################
#
# History
# -2018/11/28 - Created by Richard Thomson
# -2018/12/03 - Updated by Richard Thomson
#	- Modified the text of the user-facing prompts to provide clarity in directions.
#	- Added support for parameters based on previous JAMF Software, LLC. scripts to add 
#	  organization names/branding.
# -2019/01/29 - Updated by Richard Thomson
#   - Added additional exit codes for errors/failures to differentiate logs more easily.
#
################################################################################################
#
# Parameters
# Parameter 4 = Set Organization Name in user-facing prompts
# Parameter 5 = Number of allowed failed attempts before killing script
# Parameter 6 = Custom text for contact information in case of issues
# Parameter 7 = Custom branding, with the default being the Jamf Self Service icon

## Customize window
selfServiceBrandIcon="/Users/$3/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingimage.png"
jamfBrandIcon="/Library/Application Support/JAMF/Jamf.app/Contents/Resources/AppIcon.icns"
fileVaultIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FileVaultIcon.icns"

if [ ! -z "$4" ]
then
	orgName="$4"
fi

if [ ! -z "$6" ]
then
	haltMsg="$6"
else
	haltMsg="Please contact HelpDesk for further assistance."
fi

if [[ ! -z "$7" ]]; then
	brandIcon="$7"
elif [[ -f $selfServiceBrandIcon ]]; then
	brandIcon=$selfServiceBrandIcon
elif [[ -f $jamfBrandIcon ]]; then
	brandIcon=$jamfBrandIcon
else
	brandIcon=$fileVaultIcon
fi


## Variable Declarations
## Get the currently logged on user
curUser=$(/usr/bin/stat -f%Su /dev/console)

## Query dscl for desired user's Generated UID
curUserGUID=$(dscl . -read /Users/$curUser GeneratedUID | awk '{print $2}')

## Get OS version
OS=`/usr/bin/sw_vers -productVersion | awk -F. {'print $2'}`

## Get Macintosh HD disk identifier (e.g. disk1s1)
diskID=$(/usr/sbin/diskutil info / | grep "Device Identifier:" | awk '{print $3}')

## Checks and Balances
## Check if curUser is enabled for FileVault
userCheck=`/usr/bin/fdesetup list | awk -v usrN="$curUserGUID" -F, 'match($0, usrN) {print $1}'`
if [ "${userCheck}" != "${curUser}" ]; then
	echo "This user is not a FileVault 2-enabled user."
	exit 3
fi

## Counter for attempts
try=0
if [ ! -z "$5" ]; then
	maxTry=$5
else
	maxTry=2
fi

## Check to see if encryption process is complete
encryptCheck=`/usr/bin/fdesetup status`
statusCheck=$(echo "${encryptCheck}" | grep "FileVault is On.")
expectedStatus="FileVault is On."
if [ "${statusCheck}" != "${expectedStatus}" ]; then
	echo "The encryption process has not completed."
	echo "${encryptCheck}"
	exit 4
fi




#########################################
## Script Functions
##

passwordPrompt () {
## Get the current user's old "out of sync" password
echo "Prompting ${curUser} for the old out-of-sync password to fix password mismatch for FileVault 2."
userOldPass=`/bin/launchctl asuser $(/usr/bin/stat -f%u /dev/console) /usr/bin/osascript -e "
on run
display dialog \"In order to synchronize your passwords, the passphrase must be changed.\" & return & \"\" & return & \"Enter your OLD password for '$curUser'\" default answer \"\" with title \"$orgName - FileVault Password Sync\" buttons {\"Cancel\", \"Ok\"} default button 2 with icon POSIX file \"$brandIcon\" with text and hidden answer
set userOldPass to text returned of the result
return userOldPass
end run "`
if [ "$?" == "1" ]; then
	echo "User Canceled 'Old Password' Prompt"
	exit 0
fi



## Get the current user's current "new" password
echo "Prompting ${curUser} for the current "New" password to fix password mismatch for FileVault 2."
userNewPass=`/bin/launchctl asuser $(/usr/bin/stat -f%u /dev/console) /usr/bin/osascript -e "
on run
display dialog \"Please enter your CURRENT network password for '$curUser'\" default answer \"\" with title \"$orgName - FileVault Password Sync\" buttons {\"Cancel\", \"Ok\"} default button 2 with icon POSIX file \"$brandIcon\" with text and hidden answer
set userNewPass to text returned of the result
return userNewPass
end run "`
# check for Canceled prompt
if [ "$?" == "1" ]; then
	echo "User Canceled 'New Password' Prompt"
	exit 0
fi



## Run changePassphrase command, sending user input at prompts
try=$((try+1))
if [[ $OS -ge 13 ]]; then
	result=$(expect -c "
	log_user 0
	spawn diskutil apfs changePassphrase $diskID -user $curUserGUID
	expect \"Old passphrase for user $curUserGUID:\"
	send {${userOldPass}}   
	send \r
	expect \"New passphrase:\"
	send {${userNewPass}}   
	send \r
	expect \"Repeat new passphrase:\"
	send {${userNewPass}}   
	send \r
	log_user 1
	expect eof
	")
fi
}

successAlert () {
	/bin/launchctl asuser $(/usr/bin/stat -f%u /dev/console) /usr/bin/osascript -e "
	on run
	display dialog \"\" & return & \"Your FileVault passphrase was successfully changed.\" with title \"$orgName - FileVault Password Sync\" buttons {\"Close\"} default button 1 with icon POSIX file \"$brandIcon\"
	end run"
}

errorAlert () {
	/bin/launchctl as user $(/usr/bin/stat -f%u /dev/console) /usr/bin/osascript -e "
	on run
	display dialog \"FileVault passphrase not changed.\" & return & \"$result\" buttons {\"Cancel\", \"Try Again\"} default button 2 with title \"$orgName - FileVault Password Sync\" with icon POSIX file \"$brandIcon\"
	end run"
	if [ "$?" == "1" ]; then
		echo "User Canceled 'Try Again' prompt"
		exit 1
	else
		try=$(($try+1))
	fi
}

haltAlert () {
	/bin/launchctl as user $(/usr/bin/stat -f%u /dev/console) /usr/bin/osascript -e "
	on run
	display dialog \"FileVault passphrase not changed.\" & return & \"$haltMsg\" buttons {\"Close\"} default button 1 with title \"$orgName - FileVault Password Sync\" with icon POSIX file \"$brandIcon\"
	end run"
}



#######################
## Call main functions
while true
do
	passwordPrompt
	if [[ $result = *"Error" ]]
	then
		echo "Error changing passphrase."
		if [ $try -ge $maxTry ]
		then
			haltAlert
			echo "Quitting.. Too many failures."
			exit 1
		else
			echo $result
			errorAlert
		fi
	else
		echo "Successfully changed FileVault passphrase."
		/usr/sbin/diskutil apfs updatePreboot /
		successAlert
		exit 0
	fi
done