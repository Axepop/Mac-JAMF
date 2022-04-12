#!/bin/sh
profiles=`profiles -C -v | awk -F: '/attribute: name/{print $NF}' | grep "$4"

    if [ "$profiles" == " $4" ]; then
            echo "Profile exists"
    else
            echo "Profile does not exists"
    fi
exit 0