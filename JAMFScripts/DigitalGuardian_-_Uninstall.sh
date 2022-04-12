#!/bin/bash

sudo kextunload -b com.verdasys.dgagent 
sudo killall -9 dgdaemon 
sudo rm -Rf /dgagent 
sudo rm -Rf /usr/lib/dgagent
sudo dscl . -mcxdelete /Computers/guest com.google.Chrome ExtensionInstallForcelist