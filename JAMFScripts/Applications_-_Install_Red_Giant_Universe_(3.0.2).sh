#!/bin/sh

#  install.sh
#  Red Giant Installer
#
#  Created by Christopher Corbell on 6/16/17.
#  Copyright  2017 Red Giant. All rights reserved.
#
# This script is the command-line way to install Red Giant products.
# It must be run as sudo (will prompt for admin password from the terminal.
#
# It's designed to be run from the MacOS folder alongside rgdeploy,
# with the packages folder in the app bundle's Resources directory.

# Set timestamp variable
TS=`date -j "+%Y-%m-%d %H:%M:%S"`

FUSEOPTION="--nofusecalls"

SCRIPTDIR=`dirname "$0"`
PACKAGESDIR="/private/tmp/Universe-302-Install/Universe 3.0.2 Installer.app/Contents/Resources/packages"
RGDEPLOY="/private/tmp/Universe-302-Install/Universe 3.0.2 Installer.app/Contents/MacOS/rgdeploy"

LOGFILE="/Library/Logs/redgiant-installer-"`date +%s`".log"

echo "${TS}  -  Running Red Giant installer tool rgdeploy" > ${LOGFILE}
echo "${TS}  -  A log file for this install will be written here:" >> ${LOGFILE}
echo "${TS}  -  SCRIPTDIR:  ${SCRIPTDIR}" >> ${LOGFILE}
echo "${TS}  -  PACKAGESDIR:  ${PACKAGESDIR}" >> ${LOGFILE}
echo "${TS}  -  RGDEPLOY:  ${RGDEPLOY}" >> ${LOGFILE}
echo "${TS}  -  ..." >> ${LOGFILE}
"${RGDEPLOY}" --verbose ${FUSEOPTION} dir="${PACKAGESDIR}" log="${LOGFILE}" "$@"

