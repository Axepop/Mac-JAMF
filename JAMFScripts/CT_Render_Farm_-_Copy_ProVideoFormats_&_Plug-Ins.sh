#!/bin/bash

# Set working directories
QuickTime="/private/tmp/CT-RenderFarm_ProVideoCodecsFormats/QuickTime/"
ProWorkFlow="/private/tmp/CT-RenderFarm_ProVideoCodecsFormats/ProWorkflowPlugins/"

# Copy QuickTime files to /Library/QuickTime
/bin/echo "Copying QuickTime ProVideo Formats to /Library/QuickTime."
cp -Rv "${QuickTime}" "/Library/QuickTime/"

# Copy ProVideo WorkFlow Plug-ins to /Library/Video/Professional Video Workflow Plug-Ins
/bin/echo "Copying ProVideo WorkFlow Plug-Ins to /Library/Video/Professional Video Workflow Plug-Ins."
cp -Rv "${ProWorkFlow}" "/Library/Video/Professional Video Workflow Plug-Ins/"

exit 0