#!/bin/sh

## Variable Declarations
# Set TimeStamp (TS) variable for year|month|day Hour|Minute|Second format for easy log review/reference
TS=`date -j "+%Y-%m-%d %H:%M:%S"`
# Set date timestamp (LD) for use for logfile name
TD=`echo {$TS} | awk '{print $1}'`
# Set Logfile location path variable
LF="/Library/Logs/BigFish_CylancePROTECT_Install_${LD}.log"
# Set variable for current user for logging
CU=$(/usr/bin/stat -f%Su /dev/console)


## Main Script
# Create Log File
/bin/echo "${TS}:  Starting CylancePROTECT Install Script." >> ${LF}

# Check for presence of Cylance temporary directory, create if not exist
/bin/echo "${TS}:  Checking for presence of Cylance temporary installation directory." >> ${LF}
if [ ! -e /private/tmp/CylanceInstall/ ]; then
	/bin/echo "${TS}:    - Temporary installation directory not found. Creating..." >> ${LF}
	mkdir /private/tmp/CylanceInstall/
	if [ -e /private/tmp/CylanceInstall/ ]; then
		/bin/echo "${TS}:  Created Cylance temporary installation direcetory." >> ${LF}
	else
		/bin/echo "${TS}:  Unable to create Cylance temporary installation directory." >> {$LF}
		/bin/echo "${TS}:  Exiting script with exit code 1." >> ${LF}
		exit 1
	fi
else
	/bin/echo "Cylance temporary install directory exists. Skipping creation." >> ${LF}
fi

# Create Cylance Install Token
/bin/echo "${TS}:  Creating CylancePROTECT installation token." >> ${LF}
/bin/echo 5xE9vezxewd1j4bmWk6XNAPz > /private/tmp/CylanceInstall/cyagent_install_token
/bin/echo VenueZone="Big Fish Games Workstations" >> /private/tmp/CylanceInstall/cyagent_install_token
if [ -e /private/tmp/CylanceInstall/cyagent_install_token ]; then
	/bin/echo "${TS}:  CylancePROTECT installation token created successfully." >> ${LF}
else
	/bin/echo "${TS}:  CylancePROTECT installation token not created." >> ${LF}
	/bin/echo "${TS}:  Exiting script with exit code 1." >> ${LF}
	exit 1
fi

# Call CylancePROTECT installer
if [ -e /private/tmp/CylanceInstall/cyagent_install_token ]; then
	if [ -e /private/tmp/CylanceInstall/CylancePROTECT.pkg ]; then
		/bin/echo "${TS}:  Running CylancePROTECT installer." >> ${LF}
		installer -pkg /private/tmp/CylanceInstall/CylancePROTECT.pkg -target /
		/bin/echo "${TS}:  Installed CylancePROTECT." >> ${LF}
	else
		/bin/echo "${TS}:  Unable to run installer. Installer 'CylancePROTECT.pkg' not found!" >> ${LF}
		/bin/echo "${TS}:  Exiting script with exit code 1." >> ${LF}
		exit 1
	fi
else
	/bin/echo "${TS}:  Unable to run installer. Installation token 'cyagent_install_token' not found!" >> ${LF}
	/bin/echo "${TS}:  Exiting script with exit code 1." >> ${LF}
	exit 1
fi
