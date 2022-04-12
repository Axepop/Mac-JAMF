#!/bin/bash

## Set variables
DMG="ffmpeg-3.4.2.dmg"
App="ffmpeg"
MountedDir="/Volumes/FFmpeg 3.4.2/"

## Attach FFmpeg dmg to allow for copying of contents
if [ -e "/Library/Application Support/JAMF/Waiting Room/${DMG}" ]; then
	/bin/echo "Found DMG file in ${SourceDir}. Attempting to attach ${DMG}."
	hdiutil attach -quiet -nobrowse -noautoopen /Library/Application\ Support/JAMF/Waiting\ Room/${DMG}
	## Check for mounted volume and exit if does not exist
	if [ -e "${MountedDir}" ]; then
		/bin/echo "Attachment successful - path found at ${MountedDir}. Continuing."
	else
		/bin/echo "Attachment unsuccessful - no path found in Volumes. Exiting with Error."
		exit 1
	fi
else
	## Exit as no DMG file found
	/bin/echo "DMG file not found in ${SourceDir}. Exiting with Error."
	exit 1
fi

## Copy FFmpeg contents from volume to Applications
if [ -e "${MountedDir}" ]; then
	/bin/echo "Copying ${App} from ${MountedDir} to /Applications."
	cp -pRv "${MountedDir}${App}" /Applications/
	## Check that app exists in Applications and exit if does not exist
	if [ -e /Applications/${App} ]; then
		/bin/echo "File ${App} successfully copied to /Applications. Continuing."
	else
		/bin/echo "File ${App} not copied to /Applications. Exiting with Error."
		exit 1
	fi
else
	## Exit as no app found in Volumes
	/bin/echo "Failed to copy ${App} from ${MountedDir} to /Applications. Exiting with Error."
	exit 1
fi

## Set ownership on file
if [ -e /Applications/${App} ]; then
	/bin/echo "Setting ownership of /Applications/${App}."
	chown root:wheel /Applications/${App}
	## Check ownership of app and compare to desired outcome, exit if matches
	AppOwner=`ls -al "/Applications/${App}" | awk '{print $3,$4}'`
	if [ "${AppOwner}" == "root wheel" ]; then
		/bin/echo "Success. Ownership changed to ${AppOwner}. Continuing."
	else
		## Exit as ownership does not match desired outcome
		/bin/echo "Unsuccessful. Ownership not changed. Exiting with Error."
		exit 1
	fi
else
	## Exit as no app was found in Applications
	/bin/echo "${App} not found in /Applications. Exiting with Error."
	exit 1
fi

## Detach mounted DMG volume
hdiutil detach -quiet "${MountedDir}"
if [[ ! -e "${MountedDir}" ]]; then
	/bin/echo "No DMG Volume found. Detach successful."
    /bin/echo "Cleaning up and removing the cached package."
    rm -rf /Library/Application\ Support/JAMF/Waiting\ Room/ffmpeg*
	## Exit script
	exit 0
else
	## Volume not detached, try diskutil
	/bin/echo "Volume still exists, hdiutil detach unsuccessful. Attempting diskutil unmount."
	diskutil unmount "${MountedDir}"
	if [[ ! -e "${MountedDir}" ]]; then
		/bin/echo "No DMG Volume found. Unmount successful."
        /bin/echo "Cleaning up and removing the cached package."
        rm -rf /Library/Application\ Support/JAMF/Waiting\ Room/ffmpeg*
		exit 0
	else
		## Failed to detach and unmount volume. Exiting with Error.
		/bin/echo "Failed to detach and unmount Volume using hdiutil and diskutil."
		/bin/echo "Exiting with Error."
		exit 1
	fi
fi
