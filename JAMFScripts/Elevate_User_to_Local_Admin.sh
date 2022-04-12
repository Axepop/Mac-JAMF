#!/bin/bash

# grab current user
curUser=`ls -l /dev/console | cut -d " " -f 4`

# Make current user an admin; requires reboot
dscl . -append /Groups/admin GroupMembership $curUser

exit 0