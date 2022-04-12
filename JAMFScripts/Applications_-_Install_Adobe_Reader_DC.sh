#!/bin/sh
#####################################################################################################
#
# ABOUT THIS PROGRAM
#
# NAME
#	AdobeReaderUpdate.sh -- Installs or updates Adobe Acrobat Reader DC
#
# SYNOPSIS
#	sudo AdobeReaderUpdate.sh
#
####################################################################################################
# Script to download and install Adobe Reader.
# Only works on Intel systems.

dmgfile="reader.dmg"
logfile="/Library/Logs/AdobeReaderDCUpdateScript.log"

## Main Script
/bin/echo "-- Start Script --" >> ${logfile}
# Are we running on Intel?
if [ '`/usr/bin/uname -p`'="i386" -o '`/usr/bin/uname -p`'="x86_64" ]; then
	## Get OS version and adjust for use with the URL string
	OSvers_URL=$( sw_vers -productVersion | sed 's/[.]/_/g' )

	## Set the User Agent string for use with curl
	userAgent="Mozilla/5.0 (Macintosh; Intel Mac OS X ${OSvers_URL}) AppleWebKit/535.6.2 (KHTML, like Gecko) Version/5.2 Safari/535.6.2"

	# Get the latest version of Reader available from Adobe's About Reader page.
	latestver=``
	while [ -z "$latestver" ]
	do
	   latestver=`/usr/bin/curl -s -L -A "$userAgent" https://get.adobe.com/reader/ | grep "<strong>Version" | /usr/bin/sed -e 's/<[^>][^>]*>//g' | /usr/bin/awk '{print $2}'`
	done
	
	/bin/echo "`date`: Latest Version is: $latestver" >> ${logfile}
	latestvernorm=`echo ${latestver} | sed -e 's/20//'`
	# Get the version number of the currently-installed Adobe Reader, if any.
	if [ -e "/Applications/Adobe Acrobat Reader DC.app" ]; then
		currentinstalledver=`/usr/bin/defaults read /Applications/Adobe\ Acrobat\ Reader\ DC.app/Contents/Info CFBundleShortVersionString`
		/bin/echo "`date`: Current installed version is: $currentinstalledver" >> ${logfile}
		if [ ${latestvernorm} = ${currentinstalledver} ]; then
			/bin/echo "`date`: Adobe Reader DC is current. Exiting" >> ${logfile}
			exit 0
		fi
	else
		currentinstalledver="none"
		/bin/echo "`date`: Adobe Reader DC is not installed" >> ${logfile}
	fi
	

	ARCurrVersNormalized=$( echo $latestver | sed -e 's/[.]//g' -e 's/20//' )
	/bin/echo "`date`: Variable ARCurrVersNormalized: $ARCurrVersNormalized" >> ${logfile}
	url=""
	url1="http://ardownload.adobe.com/pub/adobe/reader/mac/AcrobatDC/${ARCurrVersNormalized}/AcroRdrDC_${ARCurrVersNormalized}_MUI.dmg"
	url2=""
	
	#Build URL	
	url=`/bin/echo "${url1}${url2}"`

	/bin/echo "`date`: Beginning Installation Script Function" >> ${logfile}
	# Compare the two versions, if they are different or Adobe Reader is not present then download and install the new version.
	if [ "${currentinstalledver}" != "${latestvernorm}" ]; then
        /bin/echo "`date`: Current Reader DC version: ${currentinstalledver}" >> ${logfile}
		/bin/echo "`date`: Available Reader DC version: ${latestver} => ${latestvernorm}" >> ${logfile}
		/bin/echo "`date`: Downloading newer version." >> ${logfile}
		/bin/echo "`date`: Latest version of the URL is: $url" >> ${logfile}
		/usr/bin/curl -s -o /tmp/reader.dmg ${url}
		/bin/echo "`date`: Mounting installer disk image." >> ${logfile}
		/usr/bin/hdiutil attach /tmp/reader.dmg -nobrowse -quiet
		/bin/echo "`date`: Installing..." >> ${logfile}
		/usr/sbin/installer -pkg /Volumes/AcroRdrDC_${ARCurrVersNormalized}_MUI/AcroRdrDC_${ARCurrVersNormalized}_MUI.pkg -target / > /dev/null
		
		/bin/sleep 10
		/bin/echo "`date`: Unmounting installer disk image." >> ${logfile}
		/usr/bin/hdiutil detach $(/bin/df | /usr/bin/grep Adobe\ Acrobat\ Reader\ DC\ Installer | awk '{print $1}') -quiet
		/bin/sleep 10
		/bin/echo "`date`: Deleting disk image." >> ${logfile}
		/bin/rm /tmp/${dmgfile}
		
		#double check to see if the new version got updated
		newlyinstalledver=`/usr/bin/defaults read /Applications/Adobe\ Acrobat\ Reader\ DC.app/Contents/Info CFBundleShortVersionString`
        if [ "${latestvernorm}" = "${newlyinstalledver}" ]; then
            /bin/echo "`date`: SUCCESS: Adobe Reader has been updated to version ${newlyinstalledver}" >> ${logfile}
            /bin/echo "`date`: -- End Script --" >> ${logfile}
	   # /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -title "Adobe Reader Updated" -description "Adobe Reader has been updated." &
        else
            /bin/echo "`date`: ERROR: Adobe Reader update unsuccessful, version remains at ${currentinstalledver}." >> ${logfile}
            /bin/echo "`date`: -- End Script --" >> ${logfile}
			exit 1
		fi
    
	# If Adobe Reader is up to date already, just log it and exit.       
	else
		/bin/echo "`date`: Adobe Reader is already up to date, running ${currentinstalledver}." >> ${logfile}
        /bin/echo "`date`: -- End Script --" >> ${logfile}
	fi	
else
	/bin/echo "`date`: ERROR: This script is for Intel Macs only." >> ${logfile}
    /bin/echo "`date`: -- End Script --" >> ${logfile}
fi

exit 0