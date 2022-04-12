#!/bin/bash

##################################################################################
#
# Copyright (c) 2016, JAMF Software, LLC.  All rights reserved.
#
#       Redistribution and use in source and binary forms, with or without
#       modification, are permitted provided that the following conditions are met:
#               * Redistributions of source code must retain the above copyright
#                 notice, this list of conditions and the following disclaimer.
#               * Redistributions in binary form must reproduce the above copyright
#                 notice, this list of conditions and the following disclaimer in the
#                 documentation and/or other materials provided with the distribution.
#               * Neither the name of the JAMF Software, LLC nor the
#                 names of its contributors may be used to endorse or promote products
#                 derived from this software without specific prior written permission.
#
#       THIS SOFTWARE IS PROVIDED BY JAMF SOFTWARE, LLC "AS IS" AND ANY
#       EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#       WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#       DISCLAIMED. IN NO EVENT SHALL JAMF SOFTWARE, LLC BE LIABLE FOR ANY
#       DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#       (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#       LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#       ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#       (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#       SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#		This script was created with the intentions of configuring the App Store options
#		in the System Preferences pref pane for all machines.
#
###################################################################################
#       Written by Dan Kubley, March 2016
###################################################################################

# Updates the main plist to enable Automatically Check for Updates
defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticCheckEnabled -bool false

# Updates the main plist to enable Download New Updates in the Background
defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticDownload -bool false

# Updates the main plist to enable Install System Data Files and Security Updates.  Both must be the same value for the checkbox to read correctly.
defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist ConfigDataInstall -bool false
defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist CriticalUpdateInstall -bool false

# Updates a second plist to enable Install App Updates
defaults write /Library/Preferences/com.apple.commerce.plist AutoUpdate -bool false

# Updates a second plist to enable Install OS X Updates
defaults write /Library/Preferences/com.apple.commerce.plist AutoUpdateRestartRequired -bool false

exit 0