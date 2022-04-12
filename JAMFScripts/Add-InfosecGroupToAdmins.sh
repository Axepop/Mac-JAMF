#!/bin/bash
#Purpose: This script will add the AD group "Infosec Security Scanning" to the "Allowed admin groups" in AD bindings when run.

LOGFILE="/private/var/log/jamf.log"

CURRENTGROUPS=`dsconfigad -show | grep "Allowed admin groups" | awk 'BEGIN {FS = "="};{print $2}' | sed 's/ //'`
NEWGROUP="Infosec Security Scanning"

if [[ $CURRENTGROUPS != *"Infosec Security Scanning"* ]]; 
    then
        dsconfigad -groups "$CURRENTGROUPS,$NEWGROUP"
fi

VALIDATEGROUPS=`dsconfigad -show | grep "Allowed admin groups" | awk 'BEGIN {FS = "="};{print $2}' | sed 's/ //'`

if [[ "$VALIDATEGROUPS" == *"Infosec Security Scanning"* ]];
    then
        echo "Admin Groups configured successfully." >> "$LOGFILE"
        exit 0
    else
        echo "Unable to set admin groups." >> "$LOGFILE"
        exit 1
fi