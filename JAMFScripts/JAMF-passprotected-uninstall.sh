#!/bin/sh
####################################################################################################
#
# Copyright (c) 2016, Netskope, Inc.  All rights reserved.
#
#
####################################################################################################
#
# SUPPORT FOR THIS PROGRAM
#
#       This program is distributed "as is" by Netskope, Inc team. Please contact Netskope support
#       team.
#
####################################################################################################
#
# ABOUT THIS PROGRAM
#
#		jamfuninstall.sh -- uninstall Netskope client app thru jmaf
#
#####################################################################################################
# version : 1.0 , this script file is introduced for jamf based uninstallation
# version : 2.0 , support added for password based uninstallation
####################################################################################################

SCRIPT_NAME=`basename "$0"`
echo "Param1 $1 Param2 $2 Param3 $3"

function print_usage()
{
	echo "Usage "
	echo " Uninstall without password"
    echo "   jamfuninstall.sh <dummy param 1> <dummy param 2> <dummy param 3>"
	echo " Uninstall with password"
    echo "   jamfuninstall.sh <dummy param 1> <dummy param 2> <dummy param 3> <password>"
}

if [[ $# -lt 3 ]] 
then
   echo "Insufficient arguments."
   print_usage
   exit 1
fi

if [[ $# -gt 3 ]]
then
	INPASSWORD="$4"
fi

/Applications/Remove\ Netskope\ Client.app/Contents/MacOS/Remove\ Netskope\ Client uninstall_me $INPASSWORD

RETCODE=$?
echo "Uninstaller exited with Return code : $RETCODE"
exit $RETCODE

