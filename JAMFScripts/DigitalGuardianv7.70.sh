#!/bin/bash

OLD_INSTALL_DIR=/dgagent
INSTALL_DIR=/usr/local/dgagent
SUDO_PW=
OVERRIDE_SETTINGS=0
IS_LEGACY_DGMC=0
OLD_VERSION=0
FORCE_REMOVE=0
CERT_GUID='{D65D8A44-D89E-F2FD-27BE-D76614A0B59D}'
SERVER_ADDR='1410dgcommp01.msp.digitalguardian.com'
SERVER_PORT='443'
User_consent='y'
SKEL_warning='1'
ISHTTPS='1'
PASSWORD='Verdasys1'
IS_ADDITIONAL_APPLICATIONS_EXCLUDED='0'
#End variables

isPlatformSupported()
{
    #Removing support for macOS 10.12 Sierra or below
    minor_osversion=10.13.0
    os_version=`sw_vers -productVersion`
    if [[ $(dgVersionToInt $os_version) -lt $(dgVersionToInt $minor_osversion) ]]; then
        echo "DG Agent is not supported on Mac OSX version: $os_version"
        exit 0
    fi
}

tempfile()
{
    local tempfile=`mktemp -q -t dgainstall $1`

    if [ "$?" -ne 0 ]; then
        echo "$0: Can't create temp file $tempfile" >&2
        exit 2
    fi

    echo -n "$tempfile"
}

tempdir()
{
    local tempdir=`mktemp -d -q -t dgainstall $1`

    if [ "$?" -ne 0 ]; then
        echo "$0: Can't create temp dir $tempdir" >&2
        exit 2
    fi

    echo -n "$tempdir"
}

embed_var()
{
    local val="${!1}"
    local quoted_val=\'${val//\'/\'\\\'\'}\'

    del_vars=("${del_vars[@]}" -e "/^$1=/ d")
    add_vars=("${add_vars[@]}" "$1=$quoted_val")
}

mod_xml()
{
    if [ -n "$3" ]; then
        sed -i "" -e "s,<$2>.*</$2>,<$2>$3</$2>," "$1"
    fi
}

cond_copy_file()
{
    if [ -n "$2" -a -f "$1" ]; then
        cp -a "$1" "$2"
    fi
}

cond_copy_dir()
{
    if [ -d "$1" -a -n "$2" ]; then
        cp -r "$1" "$2"
    fi
}

cond_compile_file()
{
    if [ -f "$2" -a -x "$1" ]; then
        "$1" "$2" "$3"
    fi
}

unpack_files()
{
    if ! [ -d "$INSTALL_DIR" ]; then
        mkdir -p "$INSTALL_DIR"
    fi
    sed -e '1,/^#Archive follows/d' "$0" |
    tar -x -o -C "$INSTALL_DIR"
}

is_installed()
{
    if [ -x "$OLD_INSTALL_DIR/dgctl" ] || [ -x "$INSTALL_DIR/dgctl" ]; then
        return 0
    else
        return 1
    fi
}

is_running()
{
    pgrep -x dgdaemon &>/dev/null;
}

stop_agent()
{
    if [ -x "$OLD_INSTALL_DIR/dgctl" ]; then
        OLD_VERSION=`$OLD_INSTALL_DIR/dgctl --version 2>&1 | grep version | awk '{print $NF}'`
        OUTPUT=`"$OLD_INSTALL_DIR/dgctl" --stop --password="$PASSWORD" 2>&1`
    elif [ -x "$INSTALL_DIR/dgctl" ]; then
        OLD_VERSION=`$INSTALL_DIR/dgctl --version 2>&1 | grep version | awk '{print $NF}'`
        OUTPUT=`"$INSTALL_DIR/dgctl" --stop --password="$PASSWORD" 2>&1`
    fi

    if [[ "$OUTPUT" =~ "Incorrect password provided." ]]; then
        echo $OUTPUT >&2
        echo "$0: Can't stop the daemon" >&2
        exit 2
    fi

    if [[ "$OUTPUT" =~ "Failed to send command to dgdaemon" ]]; then
        if [[ ! "$OUTPUT" =~ "Could not notify DGDaemon via DG kernel extension." ]]; then
            echo $OUTPUT >&2
            echo "$0: Can't stop the daemon" >&2
            exit 2
        fi
    fi

    launchctl unload /Library/LaunchDaemons/com.verdasys.dgagent.plist >/dev/null 2>&1
    killall -KILL dgdaemon >/dev/null 2>&1 # force terminate
    kextunload -b com.verdasys.dgagent >/dev/null 2>&1 # manually unload the module/kernel extension
}

clean_agent()
{
    if [ -d "/Library/dgagent" ]; then
        rm -rf "/Library/dgagent"
    fi
    launchctl remove "com.verdasys.dgagent" >/dev/null 2>&1
    unlink /Library/LaunchDaemons/com.verdasys.dgagent.plist >/dev/null 2>&1
}

save_settings()
{
    tempdir=$(tempdir)

    cp -af "$INSTALL_DIR/"{config,settings}.xml "$tempdir/"
    cp -af "$INSTALL_DIR/"{prcsflgs,dirctrl}.dat "$tempdir/"
    cp -af "$INSTALL_DIR/implicit.bin" "$tempdir/"
}

restore_saved_settings()
{
    cp -af "$tempdir/"{config,settings}.xml "$INSTALL_DIR/"
    cp -af "$tempdir/"{prcsflgs,dirctrl}.dat "$INSTALL_DIR/"
    cp -af "$tempdir/implicit.bin" "$INSTALL_DIR/"
    [ -n "$tmpdir" ] && rm -rf "$tmpdir" # cleaning-up
}

clear_data()
{
    rm -f "$INSTALL_DIR/"{.pflags,.ifilter}
}

delete_agent()
{
    if [ -x "$INSTALL_DIR/dgctl" ]; then
        if ! "$INSTALL_DIR/dgctl" --delete --password="$PASSWORD"; then
            echo "$0: Can't uninstall previous version" >&2
            exit 2
        fi
    elif [ -x "$OLD_INSTALL_DIR/dgctl" ]; then
        if ! "$OLD_INSTALL_DIR/dgctl" --delete --password="$PASSWORD"; then
            echo "$0: Can't uninstall previous version" >&2
            exit 2
        fi
    fi
}

add_fuse()
{
    FUSE_DIR="EndpointFS/macos/3.10.3"
    OSXFUSE_PACKAGE="endpointfs.fs"
    [ -d "$DGTHIRDPARTY/${FUSE_DIR}/${OSXFUSE_PACKAGE}" ] && cp -rf "$DGTHIRDPARTY/${FUSE_DIR}/${OSXFUSE_PACKAGE}" $1
}

add_openssl()
{
    cond_copy_file "$DGTHIRDPARTY/openssl/macosx/1.0.2p/x86_64/libcrypto.1.0.0.dylib" $1
    cond_copy_file "$DGTHIRDPARTY/openssl/macosx/1.0.2p/x86_64/libssl.1.0.0.dylib" $1
}

postinstall()
{
    local action=$1
    #CALLER variable is set as SILENT to distinguish between its callers by dgagent_postinstall script

    CALLER="SILENT"
    if [ ! -d "$INSTALL_DIR/ACI" -a -f ACI.zip ]; then
        xattr -d com.apple.quarantine ACI.zip >/dev/null 2>&1
        unzip ACI.zip -d "$INSTALL_DIR/"
    fi

    add_fuse "$INSTALL_DIR/"
    add_openssl "$INSTALL_DIR/"

    if [ -n "$PASSWORD" ]; then
        "$INSTALL_DIR/dgctl" --password="$PASSWORD" --setpw
    fi

    if [ -f "$INSTALL_DIR/_dgagent.distr" ]; then
        rm -f "$INSTALL_DIR/_dgagent.distr"
    fi

    "$INSTALL_DIR/dgagent_postinstall" "$INSTALL_DIR" "$IS_ADDITIONAL_APPLICATIONS_EXCLUDED" "$action" "$OLD_VERSION" "$CALLER"
    rm -f "$INSTALL_DIR/*postinstall" "$INSTALL_DIR/*preinstall"
}

is_kextUnloaded()
{
    i=1;
    kextstat | grep 'verdasys' &>/dev/null

    while [[ i -le 15 && $? == 0 ]];
    do
        if [[ i -eq 1 ]]; then
          echo -n "Waiting for uninstallation of existing agent..."
        else
          echo -n "."
        fi
        i=$((i+1));
        kextunload -b com.verdasys.dgagent >/dev/null 2>&1 # manually unload the module/kernel extension
        sleep 5s
        kextstat | grep 'verdasys' &>/dev/null
    done;

   [[ i -le 15 ]]
}

do_install()
{
    isPlatformSupported

    echo "$0: installing agent"

    if is_installed; then
        echo "Agent is already installed. Removing it."
        if [[ $FORCE_REMOVE -eq 1 ]]; then
            stop_agent
            "$INSTALL_DIR/uninst_helper" >/dev/null 2>&1
        else
            delete_agent
            if ! is_kextUnloaded; then
                echo "\nPreviously installed agent is not removed completely. Please reboot system and try again." >&2
                return
            fi
        echo -e "\nSuccesfully removed previous agent. Installing fresh agent."
        fi
    fi
    unpack_files

    cond_copy_file "$xml_file" "$INSTALL_DIR/config.xml"
    cond_copy_file "$cert_file" "$INSTALL_DIR/dgserver.cer"

    if [ $ISHTTPS -eq 1 ]; then
        if [ -z "$SERVER_PORT" ]  && [ -z "$xml_file" ]; then
            SERVER_PORT=443
        fi
    fi

    local config="$INSTALL_DIR/config.xml"
    mod_xml "$config" certificateGuid "$CERT_GUID"
    mod_xml "$config" commServerName "$SERVER_ADDR"
    mod_xml "$config" commServerPort "$SERVER_PORT"
    mod_xml "$config" commServerIsHTTPS "$ISHTTPS"
    mod_xml "$config" isFirstRun 1
    mod_xml "$config" skelSupressWarning "$SKEL_warning"
    mod_xml "$config" skelUserConsent "$User_consent"
    mod_xml "$config" machineGuid " "
    mod_xml "$config" legacyDGMCSupportForFQDN "$IS_LEGACY_DGMC"
    mod_xml "$config" logPath "$INSTALL_DIR/dg.log"
    mod_xml "$config" installDir "$INSTALL_DIR"

    postinstall install
}

dgVersionToInt()
{
    local IFS=.
    parts=($1)
    let val=100*parts[0]+parts[1]
    echo $val
}

# update or simply install agent as fall-back
do_update()
{
    isPlatformSupported

    if ! is_installed; then
        echo "The package is not installed yet!  Trying to install." >&2
        do_install
        return
    fi

    echo "$0: updating agent"

    stop_agent

    if [ -x "$OLD_INSTALL_DIR/dgctl" ]; then
        mv -f $OLD_INSTALL_DIR $(dirname $INSTALL_DIR)
    fi

    if [[ -n ${OVERRIDE_SETTINGS} && "${OVERRIDE_SETTINGS}" == "0" ]]; then
        save_settings  >/dev/null 2>&1
    fi

    clean_agent

    clear_data

    unpack_files

    if [[ -n ${OVERRIDE_SETTINGS} && "${OVERRIDE_SETTINGS}" == "0" ]]; then
        restore_saved_settings  >/dev/null 2>&1
    fi

    local config="$INSTALL_DIR/config.xml"
    mod_xml "$config" certificateGuid "$CERT_GUID"
    mod_xml "$config" commServerName "$SERVER_ADDR"
    mod_xml "$config" commServerPort "$SERVER_PORT"
    mod_xml "$config" commServerIsHTTPS "$ISHTTPS"
    mod_xml "$config" skelSupressWarning "$SKEL_warning"
    mod_xml "$config" isFirstRun 0
    mod_xml "$config" skelUserConsent "$User_consent"
    mod_xml "$config" legacyDGMCSupportForFQDN "$IS_LEGACY_DGMC"
    mod_xml "$config" logPath "$INSTALL_DIR/dg.log"
    mod_xml "$config" installDir "$INSTALL_DIR"

    postinstall update
}

do_unpack_resources()
{
    sed -e '1,/^#Archive follows/d' "$0" |
    tar -x -o Resources
}

do_archive()
{
    tmpfile="$(tempfile)"
    sed -e '1,/^#End variables/ !d' "${del_vars[@]}" "$source_file" | \
    sed -e "/^#End variables/ d" >"$tmpfile"

    for v in "${add_vars[@]}"; do
        echo "$v" >> "$tmpfile"
    done
    echo "#End variables" >> "$tmpfile"

    sed -e '1,/^#Archive follows/ !d' "$source_file" | \
    sed -e '1, /^#End variables/ d' >> "$tmpfile"

    if [ ${#add_files[@]} -gt 0 -o ${#add_dirs[@]} -gt 0 -o -n "$cert_file" -o -n "$xml_file" ]; then
        tmpdir="$(tempfile -d)"
        chmod go+rX "$tmpdir"
        sed -e '1,/^#Archive follows/ d' $source_file | tar -x -C "$tmpdir"

        for f in "${add_files[@]}"; do
            cp -a "$f" "$tmpdir"
        done

        for d in "${add_dirs[@]}"; do
            cp -a "$d"/* "$tmpdir"
        done

        cond_compile_file "$tmpdir/pcmp"      Resources/prcsflgs.dat "$tmpdir/.pflags"
        cond_compile_file "$tmpdir/impl_comp" Resources/implicit.xml "$tmpdir/.ifilter"

        cond_copy_file Resources/dirctrl.dat "$tmpdir/"

        # Integrate ACI feature if available
        if [ -f ACI.zip ]; then
            xattr -d com.apple.quarantine ACI.zip >/dev/null 2>&1
            unzip ACI.zip -d "$tmpdir"
        fi

        add_fuse "$tmpdir"
        add_openssl "$tmpdir"

        cond_copy_file "$xml_file" "$tmpdir/config.xml"
        cond_copy_file "$cert_file" "$tmpdir/dgserver.cer"

        cond_copy_dir Resources "$tmpdir/"
        cond_copy_dir "$tmpdir/"DGCIApp.app "$tmpdir/"Resources/

        tar -cz -C "$tmpdir" . >>"$tmpfile"
    else
        sed -e '1,/^#Archive follows/ d' $source_file >> "$tmpfile"
    fi

    chmod +rx "$tmpfile"
    mv "$tmpfile" "$dest_file"
}

usage()
{
cat <<EOF
Usage:
$0 [-g <guid file>] [-c <cert file>] [-s <server addr>] [-p <server port>] [-r]
   [-x <config.xml file>] [-f <file to add to archive>] [-d <dir to add to archive>]
   [-P <uninstall password>] [-i <input file>] [-o <output file>]
   [-S <sudo password>] [-k <user consent>] [-(I|U|A|R)] [-t] [-h] [-a] [-O] [-L] [-F]

    -g <file>    sets the certificate GUID from <file>
    -c <file>    embeds the certificate file <file>
    -s <addr>    sets the DGServer address or hostname
    -p <port>    sets the DGServer port
    -r        use HTTPS in DGServer connection
    -x <file>    embeds <file> as config.xml
    -f <file>    adds <file> to the archive
    -d <dir>    adds the contents of directory <dir> to archive
    -P <password>   sets the uninstall password
    -i <file>    use <file> as input archive instead of $0
    -o <file>    output to <file> instead of $0
    -S <password>    sets the password to be used with sudo
    -I        perform an installation instead of updating the package
    -U        refresh (or newly install) the package
    -R        get Resources
    -A        make/strip/extract [modified] archive for/from the package
    -t        list the archive contents
    -h        show usage information
    -a        add additional applications to /Applications folder (e.g. DGCIApp)
    -k <Y/N>    to supress warning message for SKEL use only for OSX version later than High Sierra (10.13).
    -O      overrides existing resources (applicable for upgrade only)
    -L      is legacy DGMC (DGMC version < 7.5)
    -F      removes the DGAgent forcefully and DGMC will not be notified

With -I option an installation is performed.
In this case -i and -o have no effect.

With -U the silent-install package is updated with the new settings or just newly installed as with -I.
If an output filename is specified via "-o" option a new package is generated,
otherwise the package being executed is updated in-place.

To integrate ACI feature put ACI.zip file to the same directory as this script
and perform customization step (use -c, -x, -f or -d option).
To create ACI.zip build corresponding target in dgdagent project.

If ACI.zip is present in the same directory as this script during install,
ACI will be installed automatically.

EOF
}

command()
{
    if [ -n "$command" -a "$command" != "$1" ]; then
        echo "Command re-definition \`command' ->\`${1-null}'" >&2
        exit 2
    fi

    command=$1

}

source_file="$0"
dest_file="$0"
unset -v command cert_file xml_file add_dirs add_files del_vars add_vars

if [ $# -eq 0 ]; then
    usage
    exit 0
fi

while getopts "d:f:g:c:s:p:P:i:o:x:S:k:rthIUARaOLF?" opt; do
    case $opt in
    (i)
        source_file="$OPTARG"
        ;;
    (o)
        dest_file="$OPTARG"
        ;;
    (O)
        OVERRIDE_SETTINGS=1
        embed_var OVERRIDE_SETTINGS
        ;;
    (d)
        if [ ! -d "$OPTARG" ]; then
            echo "$0: $OPTARG is not a directory"
            exit 2
        fi
        add_dirs=("${add_dirs[@]}" "$OPTARG")
        ;;
    (f)
        add_files=("${add_files[@]}" "$OPTARG")
        ;;
    (g)
        CERT_GUID="`cat \"$OPTARG\"`"
        embed_var CERT_GUID
        ;;
    (c)
        cert_file="$OPTARG"
        ;;
    (x)
        xml_file="$OPTARG"
        ;;
    (s)
        SERVER_ADDR="$OPTARG"
        embed_var SERVER_ADDR
        ;;
    (p)
        SERVER_PORT="$OPTARG"
        embed_var SERVER_PORT
        if [ $SERVER_PORT -eq 443 ]; then
            ISHTTPS=1
            embed_var ISHTTPS
        fi
        ;;
    (r)
        ISHTTPS=1
        embed_var ISHTTPS
        ;;
    (P)
        PASSWORD="$OPTARG"
        embed_var PASSWORD
        ;;
    (S)
        SUDO_PW="$OPTARG"
        embed_var SUDO_PW
        ;;

    (I)
        command "install"
        ;;
    (U)
        command "update"
        ;;
    (R)
        command "unpack_resources"
        ;;
    (A)
        command "archive"
        ;;

    (t)
        sed -e '1,/^#Archive follows/ d' "$source_file" | tar -tv
        exit 0
        ;;

    (a)
        IS_ADDITIONAL_APPLICATIONS_EXCLUDED=0
        embed_var IS_ADDITIONAL_APPLICATIONS_EXCLUDED
        ;;
    (k)
        SKEL_warning=1  # to supress SKEL warning
        User_consent="$OPTARG"
        case $User_consent in
        [YyNn] ) embed_var User_consent; embed_var SKEL_warning ;;
        *) usage;exit 1 ;;
        esac
        ;;

    (L)
        IS_LEGACY_DGMC=1
        embed_var IS_LEGACY_DGMC
        ;;
    (F)
        FORCE_REMOVE=1
        embed_var FORCE_REMOVE
        ;;

    (?|h)
        usage
        exit 0
        ;;
    esac
done

if [[ ${command=archive} =~ ^(install|update)$ ]] && ((EUID != 0)); then # gain super-user privileges
    if [ -n "$SUDO_PW" ]; then
        echo "$SUDO_PW" | sudo -S -- "$0" "$@"
    else
        sudo -n -- "$0" "$@"
    fi

    ret=$?

    ((ret == 1)) &&
    echo "$0: Couldn't gain superuser privileges: wrong or missing password" >&2

    exit $ret

else
    do_$command
fi

exit 0