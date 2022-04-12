#!/bin/bash -v

appName=("$4")

loggedInUser=$(stat -f%Su /dev/console)
echo $loggedInUser

#message information
msgprompthead="Software Restart Required"
msgrestart="This computer needs to restart to finish installation of the following application:

"${4}"

Please save any open files to external media. Restart will occur automatically in 5 minutes.

To restart immediately, please click Ok after closing all applications."

dialogicon="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/Resources/Message.png"
jamfhelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

restartprompt=$("${jamfhelper}" -windowType utility -heading "${msgprompthead}" -description "${msgrestart}" -icon "${dialogicon}" -button1 "Ok"  -defaultButton 1 -timeout 300)

sudo -u $loggedInUser pkill -u $loggedInUser
sudo -u $loggedInUser shutdown -r +1

exit 0