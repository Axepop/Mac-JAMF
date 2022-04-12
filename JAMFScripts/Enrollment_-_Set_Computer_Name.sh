#!/bin/sh

#####################################################################################
#
# Name:				Jamf_Enrollment_Rename.sh
# Creation Date:	13 Dec 2018
# Author:			Richard Thomson
#
#####################################################################################
#
# Purpose
# 
# The purpose of this script is to provide a relatively simpler experience during 
# the enrollment process for new computers. Ran before the AD binding, the script 
# prompts the administrator/user to supply a new computer name, and then updates 
# all names (ComputerName, HostName, LocalHostName). If the supplied computer name 
# is too long (longer than 15 characters), the script will error and prompt for a 
# new computer name again. If, for some reason, the supplied computer name does not 
# match a returned computer name (resulting from a simple scutil --get check), the 
# script notifies the user of this and prompts for a new computer name to reattempt 
# changing the name.
#  
#####################################################################################
#
# History
# @ 2018/12/13:  Created by Richard Thomson
# @ 2018/12/17:  Modified by Richard Thomson
#	+ Added CANCEL button to prompt to allow for backing out of rename if system had 
# 	  previously been renamed.
#	+ Added variable declaration at beginning of script that was previously not 
#	  present.
#	+ Added additional echos during function calls for logging and review purposes.
#	- Removed redundant code in functions and function calls.
#
#####################################################################################
#
# Parameters
# Parameter 4 = Set Organization Name used in user-facing prompts
# Parameter 6 = Custom text used for contact information in case of issues
# Parameter 7 = Custom branding, with the default being the Jamf Self Service icon

## Window Customizations
selfServiceBrandIcon="/Users/$3/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingimage.png"
jamfBrandIcon="/Library/Application Support/JAMF/Jamf.app/Contents/Resources/AppIcon.icns"
fileVaultIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FileVaultIcon.icns"

if [ ! -z "$4" ]; then
	orgName="$4"
fi

if [ ! -z "$6" ]; then
	haltMsg="$6"
else
	haltMsg="Please contact Helpdesk for further assistance."
fi

if [[ ! -z "$7" ]]; then
	brandIcon="$7"
elif [[ -f $selfServiceBrandIcon ]]; then
	brandIcon=$selfServiceBrandIcon
elif [[ -f $jamfBrandIcon ]]; then
	brandIcon=$jamfBrandIcon
fi

## Variables
# Get current user name
curUser=$(/usr/bin/stat -f%Su /dev/console)

## Functions
# Caution prompt reminding to Check AD to avoid duplicate objects or issues result of duplicate names
cautionNamePrompt () {
	echo "Displaying AD cautionary prompt to ${curUser}."
	/bin/launchctl asuser $(/usr/bin/stat -f%u /dev/console) /usr/bin/osascript -e "
	on run
	display dialog \"Before naming this computer, check Active Directory (AD) to ensure the name does not already exist!\" with title \"$orgName - Set Computer Name\" buttons {\"Ok\"} default button 1 with icon caution
	end run"
	if [ "$?" == "1" ]; then
		echo "${curUser} accepted the AD caution prompt."
	fi
}

# Normal Prompt for desired Computer Name
compNamePrompt () {
	echo "Prompting ${curUser} for the desired computer name."
	computerName=`/bin/launchctl asuser $(/usr/bin/stat -f%u /dev/console) /usr/bin/osascript -e "
	on run
	display dialog \"Enter new computer name\" default answer \"\" with title \"$orgName - Set Computer Name\" buttons {\"Cancel\", \"Set Name\"} default button 2 with icon POSIX file \"$brandIcon\"
	set computerName to text returned of the result
	return computerName
	end run"`
	if [ "$?" == "1" ]; then
		echo "$curUser cancelled the computer rename."
		exit 1
	elif [ "$?" == "2" ]; then
		echo "${curUser} supplied a computer name."
	fi
}

# Alert prompt for when supplied computer name is too long (greater than 15 characters)
errorAlertLength () {
	echo "${curUser} supplied a computer name '${computerName}' that was too long. Prompting ${curUser} with error message."
	/bin/launchctl asuser $(/usr/bin/stat -f%u /dev/console) /usr/bin/osascript -e "
	on run
	display dialog \"Computer Name is too long (More than 15 characters)\" & return with title \"$orgName - Set Computer Name\" buttons {\"Try Again\"} default button 1 with icon POSIX file \"$brandIcon\"
	end run"
	if [ "$?" == "1" ]; then
		echo "${curUser} clicked 'Try Again'."
	fi
}

# Alert prompt for when supplied computer name does not match what is returned from scutil --get
errorAlertMatch () {
	echo "The expected computer name '${computerName}' was not returned from scutil --get. Prompting ${curUser} with error message."
	/bin/launchctl asuser $(/usr/bin/stat -f%u /dev/console) /usr/bin/osascript -e "
	on run
	display dialog \"Computer names do not match\" & return with title \"$orgName - Set Computer Name\" buttons {\"Try Again\"} default button 1 with icon POSIX file \"$brandIcon\"
	end run"
	if [ "$?" == "1" ]; then
		echo "${curUser} clicked 'Try Again.'"
	fi
}

# Set Computer Name commands and success prompt
setCompName () {
	echo "Running scutil commands to set computer name to '${computerName}'."
	/usr/sbin/scutil --set ComputerName $computerName
    returnedCName=`scutil --get ComputerName | awk '{print $1}'`
	echo "ComputerName set to '${returnedCName}'."
	/usr/sbin/scutil --set LocalHostName $computerName
    returnedLHName=`scutil --get LocalHostName | awk '{print $1}'`
	echo "LocalHostName set to '${returnedLHName}'."
	/usr/sbin/scutil --set HostName $computerName
    returnedHName=`scutil --get HostName | awk '{print $1}'`
	echo "HostName set to '${returnedHName}'."
}

# Alert prompt for when computer name has been changed successfully
successAlert () {
	/bin/launchctl asuser $(/usr/bin/stat -f%u /dev/console) /usr/bin/osascript -e "
	on run
	display dialog \"Computer Name successfully set to '$computerName'.\" & return & return & \"Click Close to continue.\" with title \"$orgName - Set Computer Name\" buttons {\"Close\"} default button 1 with icon POSIX file \"$brandIcon\"
	end run"
	if [ "$?" == "1" ]; then
		echo "Names changed successfully. ${curUser} clicked 'Close.'"
	fi
}

## Begin Main Script
cautionNamePrompt
while true
do
	compNamePrompt
	if [[ ${#computerName} -gt 15 ]]; then
		errorAlertLength
	else
		setCompName
		if [[ "${computerName}" != "${returnedCName}" ]]; then
			errorAlertMatch
		else
			successAlert
			exit 0
		fi
	fi
done
