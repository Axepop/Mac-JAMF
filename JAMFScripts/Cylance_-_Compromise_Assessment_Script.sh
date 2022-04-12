#!/bin/bash

# Presponse Phase 1
# Cylance, Inc.
# usage: sudo bash presponse_osx.sh
# version: 2.7.0
# date: 02/11/19


###### LS THROTTLE ######
### The number of seconds (can be less than a second) to sleep between each
### file during the recursive directory listing of the root partition.
### Keep in mind that this can greatly increase the collection time. For example,
### on an average OSX host with 500,000 files, if you were to set a throttle
### of 1 second, it would take almost a week to complete the collection, but
### CPU usage for the collection process would hover around 0%. The throttle
### value, if used, should be very small (i.e. 0.02 give or take).
### Note: Not implemented yet!
LSTHROTTLE=0


###### FTP UPLOAD VARIABLES ######
### With these variables users can move the output file to an FTP server.
### UseFTP: 1=enable
### FTPHost: Hostname or address of the FTP server
### FTPUser: Username to connect with
### FTPPass: Password to connect with
### FTPCleanup: Delete the output file regardless of success/failure of FTP upload
###       1=cleanup, 0=don't cleanup
###
UseFTP=0
FTPHost=
FTPUser=
FTPPass=
FTPCleanup=0

###### SFTP UPLOAD VARIABLES ######
# Upload archives to SFTP server
# UseSFTP: 1=enable
# SFTPUser: Username to authenticate to the SFTP server
# SFTPHost: Hostname or IP address of SFTP server
# SFTPPath: Path to upload archives to
# SFTPPort: Port to connect to SFTP Server
# SFTPCleanup: Cleanup output archive regardless of success/failure
UseSFTP=1
SFTPUser=aristocrat-osx
SFTPHost=162.221.74.68
SFTPPath=data
SFTPPort=443
SFTPCleanup=0


###### CURL VARIABLES ######
### If you want to use Curl, then set the variables below.
### Be sure to use a version of curl that supports SSL. Be sure to
### create the Box folder in a location that is accessible via the
### Box API; the 'Client Uploads' folder qualifies. The version of
### curl I used requires the -k flag in order to skip cert verification.
###
### UseCurl: 1=enable
### UserEmail: Set to email address of valid Box account email address
### FolderID: Set to the ID of the destination Box folder
### CurlCleanup: Delete the output file regardless of success/failure of Box upload
###       1=cleanup, 0=don't cleanup
UseCurl=0
UserEmail=
FolderID=
CurlCleanup=0

###### Collect Chrome Extensions ######
###
### GETCHROMEEXT: 1=enable, collects the entirty of the chrome extentions. May be 
###    large depending on the system and is therefor off by default.
### GETCHROMEEXT: 0=disable, will not collect chrome extentions. 
GETCHROMEEXT=0

###### USE UNIQUE ARCHIVE NAME ######
### 
### Toggle to append host ip address and random value. This is to ensure collection of  
### hosts that have the same hostname and ip address.
### OUTPUT FILENAME: HOSTNAME---IP ADDRESS---RANDOMEVALUE.tar.gz
APPEND_RANDOM_TO_HOSTNAME=0


###### MARKER FILE ######
### Handles the creation, checking, and/or deletion of a marker file which
###   indicates whether the script has already run on a host.
###
### LEAVEMARKER: 1 = enable (leave a marker file behind)
### CHECKMARKER: 1 = enable (check whether a marker file exists; if so, terminate this script)
### DELETEMARKER: 1 = enable (deletes the marker file if it exists) (not implemented)
### MARKERPATH: The full path where the marker file will be left or checked for.
###             All parent folders specified in the path must already exist.
### MARKERFILE: The name of the marker file.
###
LEAVEMARKER=0
CHECKMARKER=0
# SET DELETEMARKER=0
MARKERFILE=/CylanceCAMarker.mkr

if [ "$CHECKMARKER" -eq "1" ] ;then
    if [ -f $MARKERFILE ] ; then
        exit
    fi
fi

# set environment variables, target directory, config settings, and initializations
# set ip and random variables
IRCASE=$(hostname)
TMPLOG=/tmp/"$IRCASE"'_Cylance-osx-errors.log'
RANDOM_STR=''
IP_ADDR=''
if [ -c '/dev/urandom' ] ; then
    RANDOM_STR=$( (cat /dev/urandom 2>&1) |
    (env LC_CTYPE=C tr -dc a-zA-Z0-9 2>&1) | 
    (head -c 8 2>&1) 2>> "$TMPLOG" 2>&1)
else
    RANDOM_STR=$(date +%s)"$$" 2>> "$TMPLOG"
fi
IP_ADDR=$( (ifconfig 2>&1) | 
    (grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' 2>&1) | 
    (grep -Eo '([0-9]*\.){3}[0-9]*' 2>&1) | 
    (grep -v '127.0.0.1' 2>&1) | 
    (sed -n '1p' 2>&1) 2>> "$TMPLOG" 2>&1)

# basename of results archive
if [ "$APPEND_RANDOM_TO_HOSTNAME" = "1" ] ; then
    ARCHIVENAME="$IRCASE"---"$IP_ADDR"---"$RANDOM_STR"
else
    ARCHIVENAME="$IRCASE"
fi
# output destination, change according to needs
LOC=/tmp/"$ARCHIVENAME"
# tmp file to redirect results
TMP="$LOC"/"$IRCASE"'_tmp.txt'
# redirect stderr and stdout
ERROR_LOG="$LOC"/"$IRCASE"'_osx-errors.log'
VERBOSE_LOG=/tmp/"$ARCHIVENAME"'_Cylance-presponse-osx.log'
mkdir "$LOC"
mv -f "$TMPLOG" "$ERROR_LOG"

# Function used in script to test if binary exists before running. 
function bin_exist {
    command -v "$1" 2>> "$VERBOSE_LOG" >> "$VERBOSE_LOG"
    return $?
}

if ! bin_exist 'zip' ; then
    echo "zip: command not found. Needed for compression. Exiting..." > "$VERBOSE_LOG"
    exit 1
fi

if [ "$UseCurl" = "1" ] ; then
    if ! bin_exist 'curl' ; then
        echo "curl: command not found. Needed for upload. Exiting..." > "$VERBOSE_LOG"
        exit 1
    fi
fi

if [ "$UseSFTP" = "1" ] ; then
    if ! bin_exist 'sftp' ; then
        echo "sftp: command not found. Needed for upload. Exiting..." > "$VERBOSE_LOG"
        exit 1
    fi
fi

if [ "$UseFTP" = "1" ] ; then
    if ! bin_exist 'ftp' ; then
        echo "ftp: command not found. Needed for upload. Exiting..." > "$VERBOSE_LOG"
        exit 1
    fi
fi


echo 'start' > "$VERBOSE_LOG" > "$ERROR_LOG"

# make target directories for results
mkdir "$LOC"/userprofiles
mkdir "$LOC"/autoruns
mkdir "$LOC"/autoruns/startupitems
mkdir "$LOC"/autoruns/system_startupitems
mkdir "$LOC"/autoruns/launchdaemons
mkdir "$LOC"/autoruns/system_launchdaemons
mkdir "$LOC"/autoruns/launchagents
mkdir "$LOC"/autoruns/system_launchagents
mkdir "$LOC"/ChromeExtensions
mkdir "$LOC"/CylanceLogs
mkdir "$LOC"/FileHashes
mkdir "$LOC"/overrides
mkdir "$LOC"/overrides/launchd
mkdir "$LOC"/fseventsd
mkdir "$LOC"/syncedrules
mkdir "$LOC"/scriptingadditions
mkdir "$LOC"/rules
mkdir "$LOC"/internetplugins
mkdir "$LOC"/diagnosticreports
mkdir "$LOC"/leases
mkdir "$LOC"/loginwindow
mkdir "$LOC"/diagnostics
mkdir "$LOC"/diagnostics/analytics
mkdir "$LOC"/diagnostics/aggregate
mkdir "$LOC"/dslocal

# collect Phase 1 data
function collect {
    echo 'start collection'
    # start timestamp
    date '+%Y-%m-%d %H:%M:%S %Z' > "$LOC"/"$IRCASE"'_osx-date.txt'

    #  Get OSX version using the darwin version
    OSXversion=${OSTYPE:6}

    # kernel extensions
    kextstat | sed 1d > "$TMP"
    while read -r Index Refs Address Size Wired Name Version Link
    do
        {
            echo -e "$Index\\t$Name\\t$Version\\t$Size\\t$Link"
            kextfind -no-paths -b "$Name" -print-dependencies
            echo ""
        } >> "$LOC"/"$IRCASE"'_osx-modules.txt'
    done < "$TMP"
    rm "$TMP"

    # kernel version details
    {
        uname -s
        uname -n
        uname -r
        uname -v
        uname -m
        uname -p
    } >> "$LOC"/"$IRCASE"'_osx-version.txt'

    # OS details
    echo 'OS details'
    plutil -convert xml1 /System/Library/CoreServices/SystemVersion.plist -o "$LOC"/"$IRCASE"'_osx-os-version.xml'

    # network interfaces
    echo 'network interfaces'
    ifconfig -a > "$LOC"/"$IRCASE"'_osx-ifconfig.txt'

    # Generates readable copy of hosts file
    echo 'copy hosts file'
    cp /private/etc/hosts "$LOC"/"$IRCASE"'_osx-Host.txt'

    # DNS namesevers
    echo 'DNS nameservers'
    cat /etc/resolv.conf > "$LOC"/"$IRCASE"'_osx-DNSNameservers.txt'

    # SafariExtensions
    echo 'safari extensions'
    cp ~/Library/Safari/Extensions/Extensions.plist "$LOC"/"$IRCASE"'_osx-SafariExtensions.txt'

    # ChromeExtensions
    echo 'chrome extensions'
    if [ "$GETCHROMEEXT" -eq "1" ] ;then
        cp -r ~/Library/Application\ Support/Google/Chrome/Default/Extensions "$LOC"/ChromeExtensions
        chmod -R =rwx,g+s "$LOC"/ChromeExtensions
    else
        echo 'CHROMEEXT != 1.'
    fi

    # CylanceLogs
    echo 'cylance logs'
    cp -r /Library/Application\ Support/Cylance/Desktop/log/ "$LOC"/CylanceLogs
    cp -r /Library/Application\ Support/Cylance/HostCache/ "$LOC"/CylanceLogs
    cp -r /Library/Application\ Support/Cylance/Optics/Logs/ "$LOC"/CylanceLogs

    # list of files
    # common OSX locations to exclude (e.g. backups, index, etc)
    EXCLUDES=(-path /Volumes -o -path /.Spotlight-V100 -o -path /Network \
    -o -path /.MobileBackups -o -path "*Application Support/AddressBook*" \
    -o -path "/Users/*/Library/Calendars*")

    echo 'ls'
    {
        echo "!"
        find -x / \( "${EXCLUDES[@]}" \) -prune -o -type f -exec ls -laT {} +
    } >> "$LOC"/"$IRCASE"'_osx-ls.txt'

    # users and groups (used when running in single mode only)
    echo 'passwd'
    cp /etc/passwd "$LOC"/"$IRCASE"'_osx-passwd.txt'
    echo 'group'
    cp /etc/group "$LOC"/"$IRCASE"'_osx-group.txt'
    
    # Recent Spotlight Searches (MRU)
    echo 'recent spotlight searches MRU'
    cp ~/Library/Application\ Support/com.apple.spotlight.Shortcuts "$LOC"/"$IRCASE"'_osx-spotlight.shortcuts.txt'

    # Logon hooks
    echo 'logon hooks'
    cp /private/var/root/Library/Preferences/com.apple.loginwindow.plist "$LOC"/"$IRCASE"'_osx-private.loginwindow.plist'
    cp /Library/Preferences/com.apple.loginwindow.plist "$LOC"/"$IRCASE"'_osx-lib.loginwindow.plist'
    cp ~/Library/Preferences/com.apple.loginwindow.plist "$LOC"/"$IRCASE"'_osx-user.loginwindow.plist'
    cp -r ~/Library/Preferences/ByHost/com.apple.loginwindow.*.plist "$LOC"/loginwindow/
    
    # overrides
    echo 'overrides'
    cp /private/var/db/launchd.db/com.apple.launchd/overrides.plist "$LOC"/overrides/"$IRCASE"'_osx-private.com.apple.launchd.overrides.plist'
    cp -r /private/var/db/launchd.db/*/overrides.plist "$LOC"/overrides/
    cp -r /private/var/db/launch.db/*/overrides.plist "$LOC"/overrides/
	cp -r /private/var/db/com.apple.xpc.launchd "$LOC"/overrides/launchd/

    # mail accounts
    echo 'mail accounts'
    cp ~/Library/Mail/V2/MailData/Accounts.plist "$LOC"/"$IRCASE"'_osx-accounts.plist'

    # opened attachments
    echo 'opened attachments'
    cp ~/Library/Mail/V2/MailData/OpenedAttachmentsV2.plist "$LOC"/"$IRCASE"'_osx-openedattachmentsv2.plist'

    # MS office logs
    echo 'MS office logs'
    cp ~/Library/Group\ Containers/*.Office/MicrosoftRegistrationDB.reg "$LOC"/"$IRCASE"'_osx-microsoftregistrationdb.reg'

    # Mail rules
    echo 'Mail rules'
    cp ~/Library/Mail/*/MailData/SyncedRules.plist "$LOC"/syncedrules/
    cp ~/Library/Mobile\ Documents/com.apple.mail/Data/*/MailData/SyncedRules.plist "$LOC"/syncedrules/

    # shutdown log
    echo 'shutdown log'
    cp /private/var/log/com.apple.launchd/launchd-shutdown.system.log "$LOC"/"$IRCASE"'_osx-shutdownlog.log'

    # screen sharing
    echo 'screen sharing'
    cp ~/Library/Preferences/com.apple.ScreenSharing.LSSharedFileList.plist "$LOC"/"$IRCASE"'_osx-screensharing.plist'
    cp /Library/Containers/com.apple.ScreenSharing/Data/Library/Preferences/com.apple.ScreenSharing.plist "$LOC"/"$IRCASE"'_osx-com.apple.screensharing.plist'

    # rules
    echo 'rules'
    cp -r /etc/emond.d/rules/ "$LOC"/rules/
    cp /System/Library/LaunchDaemons/com.apple.emond.plist "$LOC"/"$IRCASE"'_osx-com.apple.emond.plist'

    # bash profile
    echo 'bash profile'
    cp ~/.bash_profile "$LOC"/"$IRCASE"'_osx-bashprofile.txt'
    cp ~/.bashrc "$LOC"/"$IRCASE"'_osx-bashrc.txt'

    # dhcp leases
    echo 'dhcp leases'
    cp -r /private/var/db/dhcpclient/leases/ "$LOC"/leases/

    # ppp log
    echo 'ppp log'
    cp /var/log/ppp.log "$LOC"/"$IRCASE"'_osx-ppp.log'

    # sudoers
    echo 'sudoers'
    cp /etc/sudoers "$LOC"/"$IRCASE"'_osx-sudoers.txt'

    # PF Firewall
    echo 'PF firewall'
    cp /etc/pf.conf "$LOC"/"$IRCASE"'_osx-pf.conf'

    # UserAccounts_DSLOCAL
    echo 'user accounts DSLOCAL'
    cp -r /private/var/db/dslocal/nodes/Default/users "$LOC"/dslocal/

    # fsk_hfs
    echo 'fsk_hfs log'
    cp /private/var/log/fsck_hfs.log "$LOC"/"$IRCASE"'_osx-fsck_hfs.log'

    # Finder MRU
    echo 'Finder MRU'
    cp /Library/Preferences/com.apple.finder.plist "$LOC"/"$IRCASE"'_osx-finder.plist'

    # network services
    echo 'network services'
    cp /Library/Preferences/SystemConfiguration/preferences.plist "$LOC"/"$IRCASE"'_osx-systemconfig.preferences.plist'

    # internet plugins
    echo 'internet plugins'
    cp -r ~/Library/Internet\ Plug-Ins/ /Library/Internet\ Plug-Ins/ "$LOC"/internetplugins/

    # Rc Files
    echo 'Rc Files'
    cp /etc/rc.common "$LOC"/"$IRCASE"'_osx-rc.common'
    cp /etc/rc.netboot "$LOC"/"$IRCASE"'_osx-rc.netboot'

    # quicktime URLs
    echo 'quicktime URLs'
    cp ~/Library/Caches/Quicktime/downloads/TOC.plist "$LOC"/"$IRCASE"'_osx-quicktime.toc.plist'

    # scheduler
    echo 'scheduler'
    cp ~/Library/Preferences/com.apple.scheduler.plist "$LOC"/"$IRCASE"'_osx-scheduler.plist'

    # spaces and open windows
    echo 'spacesa nd open windows'
    cp ~/Library/Preferences/com.apple.spaces.plist "$LOC"/"$IRCASE"'_osx-spaces.plist'

    # sidebar
    echo 'sidebar'
    cp ~/Library/Preferences/com.apple.sidebarlists.plist "$LOC"/"$IRCASE"'_osx-sidebarlists.plist'

    # recent downloads
    echo 'recent downloads'
    cp ~/Library/Preferences/com.apple.Preview.plist "$LOC"/"$IRCASE"'_osx-preview.plist'

    # daily network infor
    echo 'daily network infor'
    cp /private/var/log/daily.out "$LOC"/"$IRCASE"'_osx-daily.out'

    # last update
    echo 'last update'
    cp /Library/Preferences/com.apple.SoftwareUpdate.plist "$LOC"/"$IRCASE"'_osx-softwareupdate.plist'

    # last backup
    echo 'last backup'
    cp /Library/Preferences/com.apple.TimeMachine.plist "$LOC"/"$IRCASE"'_osx-lastbackup.plist'

    # timemachine backup
    echo 'timemachine backup'
    cp /private/var/db/com.apple.TimeMAchine.SnapshotDates.plist "$LOC"/"$IRCASE"'_osx-timemachine.snapshotdates.plist'

    # remembered networks
    echo 'remembered networks'
    cp /Library/Preferences/SystemConfigurations/com.apple.airport.preferences.plist "$LOC"/"$IRCASE"'_osx-airport.preferences.plist'

    # last sleep
    echo 'last sleep'
    cp /Library/Preferences/SystemConfigurations/com.apple.PowerManagement.plist "$LOC"/"$IRCASE"'_osx-powermanagement.plist'

    # ScriptingAdditions
    echo 'scripting additions'
    cp -r /System/Library/ScriptingAdditions "$LOC"/scriptingadditions/

    # system admins
    echo 'system admins'
    cp /private/var/db/dslocal/nodes/Default/groups/admin.plist "$LOC"/"$IRCASE"'_osx-admin.plist'

    # diagnostic reports
    echo 'diagnostic reports'
    cp -r /Library/Logs/DiagnosticReports "$LOC"/diagnosticreports/

    # trust settings
    echo 'trust settings'
    security dump-trust-settings > "$LOC"/"$IRCASE"'_osx-security.trust.settings.txt'

    # logged in users
    echo 'logged in users'
    who -a > "$LOC"/"$IRCASE"'_osx-loggedin.users.txt'

    # locally mounted shares
    echo 'locally mounted shares'
    df -aH > "$LOC"/"$IRCASE"'_osx-mountedshares.txt'

    # defaults
    echo 'defaults'
    defaults read > "$LOC"/"$IRCASE"'_osx-defaults.txt'

    # running processes
    echo 'running processes'
    ps aeSxww > "$LOC"/"$IRCASE"'_osx-ps.txt'

    # arp
    echo 'arp'
    arp -a > "$LOC"/"$IRCASE"'_os-arp.txt'

    # network status
    echo 'network status'
    netstat -van > "$LOC"/"$IRCASE"'_osx-netstat.txt'

    # system messages (for kern debug and stuff see syslog)
    echo 'dmesg'
    dmesg > "$LOC"/"$IRCASE"'_osx-dmesg.txt'

    # list of open files
    echo 'lsof +l'
    lsof +L > "$LOC"/"$IRCASE"'_osx-lsof-linkcounts.txt'
    echo 'lsof -i'
    lsof -i > "$LOC"/"$IRCASE"'_osx-lsof-netfiles.txt'

    # list of services
    echo 'launchctl list'
    launchctl list > "$LOC"/"$IRCASE"'_osx-launchctl.txt'

    # system hardware and configuration
    echo 'system_profiler'
    system_profiler > "$LOC"/"$IRCASE"'_osx-system_profiler.txt'

    # crontab
    echo 'crontab'
    for user in $(dscl . -list /Users)
    do
         (echo "$user"
          crontab -u "$user" -l
          echo " ") >> "$LOC"/"$IRCASE"'_osx-crontab-users.txt'
    done

    cp /usr/lib/cron/cron.allow "$LOC"/"$IRCASE"'_osx-cronallow.txt'
    cp /etc/crontab "$LOC"/"$IRCASE"'_osx-crontab.txt'

    # connections attempts (previous to Mountain Lion. For 10.8 see syslog)
    echo 'securelog'
    cp /var/log/secure.log "$LOC"/"$IRCASE"'_osx-securelog.txt'

    # last logins
    echo 'last'
    last > "$LOC"/"$IRCASE"'_osx-last.txt'

    locale > "$LOC"/"$IRCASE"'_osx-locale.txt'

    # directory service
    echo 'dscacheutil -q service'
    dscacheutil -q service > "$LOC"/"$IRCASE"'_osx-dsservice.txt'
    echo 'dscacheutil -q group'
    dscacheutil -q group > "$LOC"/"$IRCASE"'_osx-dsgroup.txt'

    # syslog
    echo 'syslog'
    syslog > "$LOC"/"$IRCASE"'_osx-syslog.txt'

    # Auditlog
    echo auditlog
    praudit -x /var/audit/* > "$LOC"/"$IRCASE"'_osx-auditlog.xml'

    # .GlobalPreferences
    echo 'plutil -convert xml1'
    plutil -convert xml1 /Library/Preferences/.GlobalPreferences.plist -o "$LOC"/"$IRCASE"'_osx-global-preferences.xml'

    # StartupItems files
    echo 'startupItems files'
    for f in /Library/StartupItems/*
    do
        cp -r "$f" "$LOC"/autoruns/startupitems
    done
    for d in /System/Library/StartupItems/*
    do
        cp -r "$f" "$LOC"/autoruns/system_startupitems
    done

    # LaunchDaemons files
    echo 'LaunchDaemons files'
    for f in /Library/LaunchDaemons/*
    do
        cp -r "$f" "$LOC"/autoruns/launchdaemons
    done
    for f in /System/Library/LaunchDaemons/*
    do
        cp -r "$f" "$LOC"/autoruns/system_launchdaemons
    done

    # LaunchAgents files
    echo 'LaunchAgents files'
    for f in /Library/LaunchAgents/*
    do
        cp -r "$f" "$LOC"/autoruns/launchagents
    done
    for f in /System/Library/LaunchAgents/*
    do
        cp -r "$f" "$LOC"/autoruns/system_launchagents
    done

    # Software installation history
    echo 'software installation history'
    cp /Library/Receipts/InstallHistory.plist "$LOC"/"$IRCASE"'_osx-InstallHistory.plist'

    # Application Layer Firewall
    echo 'application layer firewall'
    cp /Library/Preferences/com.apple.alf.plist "$LOC"/"$IRCASE"'_osx-com.apple.alf.plist'

    # Boot flags
    echo 'boot flags'
    cp /Library/Preferences/SystemConfiguration/com.apple.Boot.plist "$LOC"/"$IRCASE"'_osx-com.apple.Boot.plist'

    # Coreanalytics 
    echo 'Core Analytics'
    cp /Library/Logs/DiagnosticReports/*.core_analytics "$LOC"/diagnostics/analytics
    cp /private/var/db/analyticsd/aggregates/* "$LOC"/diagnostics/aggregate
    for file in /private/var/db/analyticsd/aggregates/*
        do
          stat -f "%N,%Sm,%SB" "$file" >> "$LOC"/diagnostics/timestamps
        done

    #
    # Userprofile Propagation
    #

    # Deleted Users
    echo 'deleted users'
    cp /Library/Preferences/com.apple.preferences.accounts.plist "$LOC"/"$IRCASE"'_osx-com.apple.preferences.accounts.plist'

    # user list
    echo 'user list'
    dscacheutil -q user > "$LOC"/"$IRCASE"'_osx-userlist.txt'

    echo 'userprofiles'
    for u in /Users/*/
    do
        # set up user directory       
        user=$(echo "$u" | cut -d'/' -f3)
        mkdir "${LOC}/userprofiles/${user}"
        mkdir "${LOC}/userprofiles/${user}/launchagents"

        # ssh known hosts
        cp /Users/"$user"/.ssh/known_hosts "${LOC}/userprofiles/${user}"

        # user shell history
        for f in /Users/"$user"/.*_history; do
            count=0
            while read -r line
            do
                echo "$f" "$count" "$line" >> "${LOC}/userprofiles/${user}/shellhistory.txt"
                count=$((count+1))
            done < "${f}"
        done

        # password hashtypes
        pwpolicy -u "$user" -gethashtypes > "${LOC}/userprofiles/${user}/hashtypes.txt"

        # user launchagents
        for la in /Users/"$user"/Library/LaunchAgents/*
        do
            cp "$la" "${LOC}/userprofiles/${user}/launchagents"
        done

        # recent items
        plutil -convert xml1 /Users/"$user"/Library/Preferences/com.apple.recentitems.plist -o "${LOC}/userprofiles/${user}/recentitems.xml"

        # Quarentine Events
        if [[ "$OSXversion" -ge 11 ]]; then
          sqlite3 /Users/"$user"/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2 <<EOL
.mode csv
.output ${LOC}/userprofiles/$user/quarentineevents.csv
SELECT LSQuarantineEventIdentifier,LSQuarantineTimeStamp,LSQuarantineAgentBundleIdentifier, \
LSQuarantineAgentName,LSQuarantineDataURLString,LSQuarantineSenderName, \
LSQuarantineSenderAddress,LSQuarantineTypeNumber,LSQuarantineOriginTitle, \
LSQuarantineOriginURLString,LSQuarantineOriginAlias FROM LSQuarantineEvent;
EOL
        fi
    done


    # Root shell history
    echo 'shellhistory'
    mkdir "$LOC"/userprofiles/'root'
    cp /private/var/root/.sh_history "$LOC"/userprofiles/'root'/'shellhistory.txt'

    #
    # Build and Application Inconsistencies
    #

    # system information
    echo 'plutil system version'
    plutil -convert xml1 /System/Library/CoreServices/SystemVersion.plist -o "$LOC"/"$IRCASE"'_osx-system_version.txt'

    # Collect hashes files with executable perms from common dirs
    echo 'hashing'
    find /Users/*/Library \( "${EXCLUDES[@]}" \) -prune -o -type f -perm +111 -exec shasum -a 256 '{}' \; >> "$LOC"/FileHashes/UsersLibrary'_osx_macho_hashes.txt'

    find /Users/*/Desktop/ -type f -perm +111 -exec shasum -a 256 '{}' \; >> "$LOC"/FileHashes/UsersDesktop'_osx_macho_hashes.txt'

    find /Users/*/Downloads/ -type f -perm +111 -exec shasum -a 256 '{}' \; >> "$LOC"/FileHashes/UsersDownloads'_osx_macho_hashes.txt'

    find /Library/Application\ Support/ -type f -perm +111 -exec shasum -a 256 '{}' \; >> "$LOC"/FileHashes/ApplicationSupport'_osx_macho_hashes.txt'

    find /Library/LaunchAgents/ -type f -perm +111 -exec shasum -a 256 '{}' \; >> "$LOC"/FileHashes/LaunchAgents'_osx_macho_hashes.txt'

    find /Library/LaunchDaemons/ -type f -perm +111 -exec shasum -a 256 '{}' \; >> "$LOC"/FileHashes/LaunchDaemons'_osx_macho_hashes.txt'

    find /tmp/ -type f -perm +111 -exec shasum -a 256 '{}' \; >> "$LOC"/FileHashes/tmp'_osx_macho_hashes.txt'

    find /Library/Extensions/ -type f -perm +111 -exec shasum -a 256 '{}' \; >> "$LOC"/FileHashes/Extensions'_osx_macho_hashes.txt'

    # Network Usage
    #
    # Query sqlite instead of grabbing the DB itself, because windows
    #    python 2.7 pysqlite version and sqlite version do not match OSX.
    sqlite3 /private/var/networkd/netusage.sqlite <<EOL
.mode csv
.output ${LOC}/${IRCASE}_osx-networkattachment.csv
SELECT zpk.z_name,zna.zidentifier, zna.zoverallstaymean, zna.zoverallstayvar, \
zna.zfirsttimestamp,zna.ztimestamp FROM znetworkattachment zna,z_primarykey zpk \
WHERE zna.z_ent = zpk.z_ent ORDER BY zpk.z_name;
EOL

    sqlite3 /private/var/networkd/netusage.sqlite <<EOL
.mode csv
.output ${LOC}/${IRCASE}_osx-liveusage.csv
SELECT zpk.z_name,zp.zprocname,zlu.ztimestamp,zlu.zwifiin,zlu.zwifiout,zlu.zwiredin,\
zlu.zwiredout,zlu.zwwanin,zlu.zwwanout FROM zprocess zp,zliveusage zlu, z_primarykey \
zpk WHERE zp.z_ent = zpk.z_ent AND zp.z_pk = zlu.zhasprocess ORDER BY zpk.z_name;
EOL

    sqlite3 /private/var/networkd/netusage.sqlite <<EOL
.mode csv
.output ${LOC}/${IRCASE}_osx-networkprocesses.csv
SELECT zpk.z_name,zp.zprocname,zp.zfirsttimestamp,zp.ztimestamp FROM zprocess \
zp,z_primarykey zpk WHERE zp.z_ent = zpk.z_ent ORDER BY zpk.z_name;
EOL

    # Authorization db
    sqlite3 /var/db/auth.db <<EOL
.separator ^ \\r\\n
.output ${LOC}/${IRCASE}_osx-authdb.csv
select r.name, mch.plugin, mch.param, r.type, r.class, r.'group', r.kofn, r.timeout, \
r.flags, r.tries, r.version, r.created, r.modified, r.identifier, r.comment \
from rules r left join mechanisms_map map on r.id = map.r_id \
left join mechanisms mch on map.m_id = mch.id order by r.id;
EOL

    # Spotlight search for files with source location metadata.
    # Writes to plist and also writes hashes to a txt file.
    mdfind -0 "kMDItemWhereFroms == *" | \
    tee >(xargs -0 mdls -plist "${LOC}/${IRCASE}_osx-sourcelocfiles.plist" -name kMDItemWhereFroms -name kMDItemPath \
        -name kMDItemContentCreationDate -name kMDItemContentModificationDate -name kMDItemFSOwnerUserID \
        -name kMDItemFSSize -name kMDItemAuthors)\
    |xargs -0 shasum -a 256 > "${LOC}/${IRCASE}_osx-sourcelocfileshashes.txt"

    # Spotlight search for app usage timestamps.
    mdfind -0 "kMDItemContentType ==com.apple.application-bundle" | \
    xargs -0 mdls -plist "${LOC}/${IRCASE}_osx-appusage.plist" -name kMDItemPath -name kMDItemLastUsedDate \
    -name kMDItemUseCount -namekMDItemUsedDates -name kMDItemWhereFroms -name kMDItemContentCreationDate \
    -name kMDItemContentModificationDate -name kMDItemFSOwnerUserID -name kMDItemFSSize -name kMDItemAuthors

    # collect root (assuming script is run as root) mailbox if less than 2mb
    if [ "$MAIL" ] && [ -f "$MAIL" ] && [[ $(du -m "$MAIL" | cut -d '/' -f 1) -lt 2 ]]; then
        cp "$MAIL" "$LOC"/"$IRCASE"'_osx-rootmail.txt'
    fi

    # end timestamp
    date '+%Y-%m-%d %H:%M:%S %Z' >> "$LOC"/"$IRCASE"'_osx-date.txt'
}

# run collect and catch errors
ERRORS=$(collect 2>&1)
{ echo "$ERRORS"; echo "TAR START"; } >> "${VERBOSE_LOG}"

# log errors
echo "$ERRORS" >> "$ERROR_LOG"

# create zip file and clean up
cd "$LOC" 2>> "$VERBOSE_LOG" || exit
zip -9r "/tmp/${ARCHIVENAME}.zip" -- * >> "$VERBOSE_LOG" 2>&1
if [ ! "$?" = "0" ] ; then
    echo "zip: command failed, could not create host archive. Exiting..." >> "$VERBOSE_LOG"
    exit 1
fi
echo "TAR END" >> "$VERBOSE_LOG"
rm -rf "$LOC"

if [ "$UseCurl" = "1" ] ; then
    curl -F new_file_1=@"/tmp/$ARCHIVENAME.zip" -F uploader_email="$UserEmail" https://upload.box.com/api/1.0/upload/vp3xvh6hm0lqdtsngna3a6nvkq4qw69d/$FolderID -k
    if [ "$CurlCleanup" = "1" ] ; then
        rm -f "/tmp/$ARCHIVENAME.zip"
    fi
fi >> "$VERBOSE_LOG" 2>&1

if [ "$UseFTP" = "1" ] ; then
    ftp -p -n $FTPHost <<SCRIPT
    user $FTPUser $FTPPass
    put "/tmp/$ARCHIVENAME.zip" "$ARCHIVENAME.zip"
    quit
SCRIPT
    if [ "$FTPCleanup" = "1" ] ; then
        rm -f "/tmp/$ARCHIVENAME.zip"
    fi
fi >> "$VERBOSE_LOG"

if [ "$UseSFTP" = "1" ] ; then
    sftp -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -P $SFTPPort $SFTPUser@$SFTPHost:$SFTPPath/ <<SCRIPT
    put "/tmp/$ARCHIVENAME.zip"
    quit
SCRIPT
    if [ "$SFTPCleanup" = "1" ] ; then
        rm -f "/tmp/$ARCHIVENAME.zip"
    fi
fi >> "$VERBOSE_LOG" 2>&1

if [ "$LEAVEMARKER" -eq "1" ] ; then
    touch "$MARKERFILE"
fi

if [ "$CurlCleanup" = "1" ] || [ "$FTPCleanup" = "1" ] || [ "$SFTPCleanup" = "1" ] ; then
    rm -f "$VERBOSE_LOG"
fi

exit
