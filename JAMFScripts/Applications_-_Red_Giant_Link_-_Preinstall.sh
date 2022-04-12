#!/bin/sh

# Test path to Red Giant Link directory, create if not exist
if [ -e "/Users/Shared/Red Giant/Link/" ]; then
	/bin/echo "Red Giant Link directory found. Checking permissions."
    chown root:wheel "/Users/Shared/Red Giant/"
    chown root:wheel "/Users/Shared/Red Giant/Link/"
    chmod a+rwx,g+rwx "/Users/Shared/Red Giant/"
    chmod a+rwx,g+rwx "/Users/Shared/Red Giant/Link/"
    /bin/echo "Done."
else
	/bin/echo "Red Giant Link directory not found. Creating."
    mkdir "/Users/Shared/Red Giant/"
    mkdir "/Users/Shared/Red Giant/Link/"
    if [ -e "/Users/Shared/Red Giant/Link/" ]; then
    	# Set ownership and permissions on parent directory "Red Giant"
    	chown root:wheel "/Users/Shared/Red Giant/"
    	chmod a+rwx,g+rwx "/Users/Shared/Red Giant/"
    	# Set ownership and permissions on child directory "Link"
    	chown root:wheel "/Users/Shared/Red Giant/Link"
    	chmod a+rwx,g+rwx "/Users/Shared/Red Giant/Link/"
    	/bin/echo "Done."
    else
    	/bin/echo "Unable to create directory structure."
    fi
fi