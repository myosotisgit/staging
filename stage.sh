#!/usr/bin/bash
#
# Server provisioning script for new Ubuntu and Larave forge servers.
#
# This script will install applications and configure them on a fresh Ubuntu OS
# Compatible with: Unbuntu 24.04 LTS
#
# The script is wrapped inside a function to protect against the connection being interrupted
# in the middle of the stream.

set -euo pipefail

#*****************************************************************
# SCRIPT DEFAULT SETTINGS
# Override these settings in ubstage.conf
#
#*****************************************************************

#*****************************************************************
# SCRIPT FUNCTIONS 
#
# Script functions that are required and should be available before application functions
#
#*****************************************************************

#-----------------------------------------------
# Function
# Root check
# This script must be run as root

function chkRoot() {
	
   if [[ ! "$(whoami)" = "root" ]]; then
    echo "Error: You must run this script as root"
   fi
} # END of function

# Run required function
chkRoot

# ----------------------------------------------
# Function
# Check if a given command/application is available.
# Expects: array of commands (see usedAppsArray)
# Returns: true/false
# Note: Also returns false when command is incorrect
function chkCommands() {

# load array
local appsToCheck=("$@")

for app in "${appsToCheck[@]}"; do
    if [ ! -x "$(command -v $app)" ]; then
        echo "Error: the command $app was not found on this system. Check usedAppsArray. Exiting...."
        exit 1
		fi
done
} # END of function

# Executing required function
chkCommands "${usedAppsArray[@]}"

# ----------------------------------------------
# Function areYouSure
function areYouSure() {
    read -p "Continue (Y/N)? : " answer
   case $answer in
      [yY] )
          echo "Continuing with script..."
         ;;
     [nN] )
         echo "Exiting..."
         exit 1
         ;;
     * )
         echo "Incorrect choice. Choose Y/N next time... "
         exit 1
         ;;
   esac
} # END of function

# ----------------------------------------------
# Function
# Section header
function sectionHeader() {

        if [ -z "$1" ]; then
        header_title="No section title"
        else
        header_title="$1"
        fi
        echo "$(colorYellow '----------------------------------------------')"
        echo "$header_title"
        echo "$(colorYellow '----------------------------------------------')"

} # END of function 

#************************************************************************
#
# MAIN APPLICATION START
#
# Required script functions are already executed
#************************************************************************

function main() {
    # Start main script
    showIntro
    areYouSure

case $stage_type in
	forge)
		log info "Staging type is set to $stage_type"
		# Ubuntu business
        #hardenSSH
		#setMaxSizeJournal
        #configUnattendedUpgrades
        #installNtpsec
		#hushMotd
        # Applications
        #setupRkhunter tech@myosotis-ict.nl
        #setupLynis
		# forge business
		#addFirewallRulesForge
		#customGitBranches
        
	;;
	ubuntu)
		log info "Staging type is set to $stage_type (default)"
		#setHostname
		#setTimezone
		#hardenSSH
        #hushMotd
		#configUnattendedUpgrades
        #setMaxSizeJournal
		#installNtpsec
        # Applications
        #setupRkhunter tech@myosotis-ict.nl
		#setupLynis
	;;
esac

sectionHeader "Staging script has completed. Reboot the system"
}

# Start main function
main 

# END of startmain=1 