#!/bin/bash

## define time servers
timeserver1="svc01.sea.bigfishgames.com"
timeserver2="time.apple.com"

touch /private/etc/ntp.conf
systemsetup -setusingnetworktime off
mv /private/etc/ntp.conf /private/etc/ntp.conf.orig
echo "server $timeserver1" > /private/etc/ntp.conf
echo "server $timeserver2" >> /private/etc/ntp.conf
systemsetup -setusingnetworktime on