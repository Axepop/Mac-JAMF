#!/bin/bash

##############
# TempAdmin.sh
# This script will give a user 30 minutes of Admin level access.
# It is designed to create its own offline self-destruct mechanism.
##############

##USERNAME=`who |grep console| awk '{print $1}'`

USERNAME=$(ls -l /dev/console | awk '/ / { print $3 }')

# create LaunchDaemon to remove admin rights
#####
echo "<?xml version="1.0" encoding="UTF-8"?> 
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"> 
<plist version="1.0"> 
<dict>
    <key>Disabled</key>
    <true/>
    <key>Label</key> 
    <string>com.yourcompany.adminremove</string> 
    <key>ProgramArguments</key> 
    <array> 
        <string>/Library/Scripts/removeTempAdmin.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>$4</integer> 
</dict> 
</plist>" > /Library/LaunchDaemons/com.yourcompany.adminremove.plist
#####

# create admin rights removal script
#####
echo '#!/bin/bash
USERNAME=`cat /var/somelogfolder/userToRemove`
/usr/sbin/dseditgroup -o edit -d $USERNAME -t user admin
rm -f /var/somelogfolder/userToRemove
rm -f /Library/LaunchDaemons/com.yourcompany.adminremove.plist
rm -f /Library/Scripts/removeTempAdmin.sh
exit 0'  > /Library/Scripts/removeTempAdmin.sh
#####

# set the permission on the files just made
chown root:wheel /Library/LaunchDaemons/com.yourcompany.adminremove.plist
chmod 644 /Library/LaunchDaemons/com.yourcompany.adminremove.plist
chown root:wheel /Library/Scripts/removeTempAdmin.sh
chmod 755 /Library/Scripts/removeTempAdmin.sh

# enable and load the LaunchDaemon
defaults write /Library/LaunchDaemons/com.yourcompany.adminremove.plist Disabled -bool false
launchctl load -w /Library/LaunchDaemons/com.yourcompany.adminremove.plist

# build log files in /var/somelogfolder
mkdir /var/somelogfolder
TIME=`date "+Date:%m-%d-%Y TIME:%H:%M:%S"`
echo $TIME " by " $USERNAME >> /var/somelogfolder/30minAdmin.txt

# note the user
echo $USERNAME >> /var/somelogfolder/userToRemove

# give current logged user admin rights
/usr/sbin/dseditgroup -o edit -a $USERNAME -t user admin

# notify
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -icon /Applications/Utilities/Keychain\ Access.app/Contents/Resources/Keychain_Unlocked.png -heading 'Temporary Admin Rights Granted' -description "
Please use responsibly. 
All administrative activity is logged. 
Access expires in 30 minutes." -button1 'OK' > /dev/null 2>&1 &

exit 0