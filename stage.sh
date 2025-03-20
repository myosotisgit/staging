#!/usr/bin/bash
#
# Server provisioning script for new Ubuntu and Larave forge servers.
#
# This script will install applications and configure them on a fresh Ubuntu OS
# Compatible with: Unbuntu 24.04 LTS
#
# The script is wrapped inside a function to protect against the connection being interrupted
# in the middle of the stream.
#
# Command: curl -L https://github.com/myosotisgit/staging/raw/refs/heads/main/stage.sh | bash -s -h

set -euo pipefail
#set -x

#*****************************************************************
# SCRIPT DEFAULT SETTINGS
# Override these settings in ubstage.conf
#
#*****************************************************************

# Script version
version="1.0";

# Run level
# Value: true (default) false
# Can be enabled using script arguments
dry_run=true;

# Stage type
# which type of staging should be executed. Default is "ubuntu"
# Values: ubuntu, postforge
stage_type="ubuntu"

# log level
# values: trace, debug, info, notice (verbose), warning, error, fatal
# default: warning
# Can be set with the log level argument
log_level="debug"
user_log_level="" # Can be set via commandline. Must be defined when running 'set -u'

# Log route
# default set to 'screen'
# Do NOT change this value. Use ubstage.conf
log_route="screen"

# Default configuration filename
config_file="ubstage.conf"
config_file_sample="ubstage.conf-sample"
repo_ubstage_folder_name="tooling.git"

# SERVER CONFIG VARIABLES
# Do not use a trailing slash!
user_home_dir="/home/forge"

#*****************************************************************
# SCRIPT INTERNAL CONSTANTS AND SETTINGS
#
#*****************************************************************

# Commands/applications used by this script that should be available for bash
usedAppsArray=("journalctl" "tee" "whoami" "basename" "dirname" "timedatectl" "getopt")
installDependenciesArray=("figlet" "zip" "unzip")

# Log level array
# log level MUST match the log level color definition array logColors[]
declare -A logLevels
logLevels[trace]=0
logLevels[debug]=1
logLevels[info]=2
logLevels[notice]=3
logLevels[warning]=4
logLevels[error]=5
logLevels[fatal]=6

# Color Variables
# These color variables are used in the color functions
# Note: when adding a new color also create the color function below
# Bash color generator: https://robotmoon.com/bash-prompt-generator/
# See also: https://stackoverflow.com/a/4332530
colorgreen='\e[1;32m'
colorblue='\e[1;34m'
colorblue='\033[1;34m'
colorred='\e[1;31m'
coloryellow="\033[1;33m"
colororange='\033[1;31m'
# Reset color
colorclear='\e[0m'

# Array with log level color definitions
# See function log()
declare -A logColors
logColors["fatal"]='\e[38;5;196m' # Red
logColors["error"]='\e[38;5;160m' # Red
logColors["warning"]='\e[38;5;208m' # orange
logColors["notice"]='\e[38;5;11m' # yellow
logColors["info"]='\e[38;5;15m' #white
logColors["debug"]='\e[38;5;248m' #gray
logColors["trace"]='\e[38;5;248m' # Gray
logColors["reset"]='\033[0m'    # Reset color


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
#----------------------------------------------------------
# Function
#  Locate and set script name and paths to read the config file
# The script can be started from any location (if in $PATH) or by calling the script root path
# In both case we need to load the config file
function setPaths() {
	
    current_path=`pwd`
    script_name=`basename "$0"` # path used to execute this script
    script_path=`dirname "$0"` # is empty when executed from .
    self_path="${0}" #Path and script that was executed

    # When this script is installed in the local PATH and executed without
    # specifying a path, the $PATH environment variable is used to locate the script
    script_env_path=`command -v ${0}`

    # Set datetime when this script started
    datetime_start=$(date +"%Y-%m-%d_%I_%M_%p")

    # Debugging
    # log function might not be available. Check that
    # if declare -f "log" >/dev/null; then
    #     log debug "setPath: path found and set to"
    #     log debug "current_path: $current_path, script_name: $script_name, script_path: $script_path, self_path: $self_path, script_env_path: $script_env_path"
    # else
    #     echo "-- setPath: path found and set to"
    #     echo "-- current_path: $current_path, script_name: $script_name, script_path: $script_path, self_path: $self_path, script_env_path: $script_env_path"
    # fi

} # END of function

# Executing required function
setPaths

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
        return 1
    fi
done
} # END of function

# Executing required function
chkCommands "${usedAppsArray[@]}"

# ----------------------------------------------
# Function areYouSure
function areYouSure() {
   read -p "Continue (Y/N)? : " answer </dev/tty
    #read -p "Continue (Y/N)? : " answer 
   case $answer in
      [yY] )
          echo "Continuing with script..."
         ;;
     [nN] )
         echo "Exiting..."
         return 1
         ;;
     * )
         echo "Incorrect choice. Choose Y/N next time... "
         return 1
         ;;
   esac
} # END of function

#----------------------------------------------------------
# Function
# Color Functions
#

function colorGreen(){
        echo -e $colorgreen$1$colorclear
}
function colorBlue(){
        echo -e $colorblue$1$colorclear
}
function colorRed(){
        echo -e $colorred$1$colorclear
}
function colorYellow(){
        echo -e $coloryellow$1$colorclear
}
function colorOrange(){
        echo -e $colororange$1$colorclear
}

#----------------------------------------------------------------
# Function
# logFileCheck()
# The available log routes are: screen, file
#
# Usage: logFileCheck <log_route> <log_path> <current path>
#
# Global arguments
# log_file_name_path
#
# Returns (global)
# log_file_name_path: full path and filename to log file

function logFileCheck() {

   # Read arguments
   #echo "Started function logFileCheck: logFileCheck arguments are: $@"
   local log_route_local="$1"
   local log_path_local="$2"
   local current_path_local="$3"

    # log file name
   local datetime_prefix=$(date +"%Y-%m-%d")
   local log_filename="ubstage-$datetime_prefix.log"


      if [[ "$log_route_local" == "file" ]]; then
         #echo "Log route was set as argument to: $log_route_local"

         # Check if log_path is set to empty or its default
         if [[ -z "$log_path_local"  || "$log_path_local" =~ "_DEFAULT" ]]; then
            #echo "log path has not been set or set to default. Using current path"
            # log path has not been set or set to default. Using current path
            log_file_name_path="$current_path_local/$log_filename"
            # Test if log file already exists
            if [[ ! -w "$log_file_name_path" ]]; then
                #echo " Creating log file: $log_file_name_path"
                # Creating log file
               touch "$log_file_name_path"
            fi
            echo "Logging is enabled. Log file is: $log_file_name_path"
            echo "**********************************************************" >>"$log_file_name_path"
            echo "* Log started: $datetime_start." >>"$log_file_name_path" >>"$log_file_name_path"
            echo "* Default log level: $log_level. User log level: $user_log_level" >>"$log_file_name_path"
            if [[ "$log_level" != "info" ]]; then
               echo "Set log level to 'info' to view default messages in this log file" >>"$log_file_name_path"
            fi 
            echo "**********************************************************" >>"$log_file_name_path"
         else
            #echo "Log path was already set to: $log_path_local. Using that"
            # Log path has been set. Check for availability and writability
            if [[ -d "$log_path_local" && -w "$log_path_local" ]]; then
               #echo "Log path is writable for $log_path_local"
               # log path exists and is writable
               log_file_name_path="$log_path_local/$log_filename"
               if [[ ! -w "$log_file_name_path" ]]; then
                   # Creating log file
                  touch "$log_file_name_path"
               fi
               echo "Logging is enabled. Log file is: $log_file_name_path"
               echo "**********************************************************" >>"$log_file_name_path"
               echo "* Log started: $datetime_start." >>"$log_file_name_path" >>"$log_file_name_path"
               echo "* Default log level: $log_level. User log level: $user_log_level" >>"$log_file_name_path"
               if [[ "$log_level" != "info" ]]; then
                  echo "Set log level to 'info' to view default messages in this log file" >>"$log_file_name_path"
               fi 
               echo "**********************************************************" >>"$log_file_name_path"
            else
               #echo "Log path is NOT writable for $log_path_local"
               # log path does not exists or is not writable
               colorOrange "Warning: The log path ($log_path), set in ubstage.conf, does not exists or is not writable. Logging to file is disabled"
               # Reset log file name and path to override setting in ubstage.conf that is not correct
               log_file_name_path=""
            fi
         fi # END of if log_path
      fi # END of if log_route=file

} # END of function


#----------------------------------------------------------------
# log()
# Function that logs to a configured log route
# The available log route are: screen, file
#
# Usage: log <log level> <message>
# 
# Log levels
# 0 - trace:  Increasing level of details
# 1 - debug:  Debugging messages
# 2 - info:   Informational messages
# 3 - notice:  (verbose), ormal, but significant conditions
# 4 - warn:   Warning conditions
# 5 - error:  Error conditions
# 6 - fatal:  Fatal conditions
# 
# Global arguments
# -_log_level
# - user_log_level (cmd line argument)
# - log_color
# - log_route
# - log filename and path (log_file_name_path)


function log() {

   # Read arguments
   #Not logging the log function :-p
   #echo "Arguments fo log(): $@"
   #echo "Globals are: user log level: $user_log_level, log route: $log_route, log file: $log_file_name_path"
   local log_level_arg="$1"
   shift 1
   local log_message="$@"
   local log_route_local="$log_route"

   if [ -z "$log_level_arg" ] || [ -z "$log_message" ]; then
       # Cannot use the log function within itself
       colorRed "Fatal: Incorrect arguments for function log(): $log_level_arg, $log_message, $@";
       return 1;
   fi

   # Is log level set by user (via command line) ?
   if [[ -n "$user_log_level" ]]; then
       log_level="$user_log_level"
   fi

    # Check if level exists
    # See https://stackoverflow.com/q/48086633 for the magic
    # not sure how the 'return 1 and return 2' actually work
    # Check if level exists
    # commented this section because using set -eou will fail because of return 2....
    #
#	[[ ${logLevels[$log_level_arg]} ]] || {
 #   	echo "Log level ${log_level_arg} does not exist"
  #  	return 1  # or continue gracefully
#	}

	# Check if level is enough
#	if (( ${logLevels[$log_level_arg]} < ${logLevels[$log_level]} )); then
 #   	echo "Log level ${log_level_arg} is too low"
    	#return 2  # or handle as needed
#	fi

    #log here
    local logcolor=${logColors[$log_level_arg]}
    if [[ "$log_route_local" == "file" && "$log_file_name_path" ]]; then
      echo -e $logcolor"${log_level_arg}: ${log_message}"${logColors["reset"]} >>"$log_file_name_path"
    else
      echo -e $logcolor"${log_level_arg}: ${log_message}"${logColors["reset"]}
    fi

    # Exit app when log level is 'error' or 'fatal'
    if [[ "$log_level_arg" == "error" || "$log_level_arg" == "fatal" ]]; then
      if [[ "$log_route_local" == "file" ]]; then
         echo -e $logcolor"${log_level_arg} error occured. Exiting program..."${logColors["reset"]} >>"$log_file_name_path"
      else
         echo -e $logcolor"${log_level_arg} error occured. Exiting program..."${logColors["reset"]}
      fi
      exit 1
    fi


} # END of function

isPackageInstalled() {
    local package="$1"

    # Check if the package is installed
    dpkg -l | grep -qw "$package" || return 1

    # Check if a systemd service with the same name is active
    if systemctl list-units --type=service --all | grep -q "^.*${package}.*active"; then
        return 0
    else
        return 1
    fi
}

# ----------------------------------------------
# Dry run function

function dryRun() {
  printf -v cmd_str '%q ' "$@"

  if [[ $dry_run == 'true' ]]; then
      echo "Dry-run: not executing $cmd_str" >&2
  else
      eval "$cmd_str"
  fi
}

# ----------------------------------------------
# Show the intro header when starting script

function showIntro() {
        # Logging
        log debug "Started function ${FUNCNAME[0]} "

        echo "$(colorYellow '----------------------------------------------')"
        echo "$(colorYellow ' Ubuntu staging script')"
        echo "$(colorYellow ' Version: ')$version";
        if [ $dry_run = true ]; then 
           echo "$(colorYellow ' Dry run:') enabled" 
        fi;
        echo "$(colorYellow ' Staging type: ')$stage_type";
        echo "$(colorYellow ' Description:')";
        echo " UBstage can stage a fresh Ubuntu OS and runs post-configuration scripts to improve the configuration and security of Forge installed servers";
        echo "$(colorYellow '----------------------------------------------')"
        echo ""
        echo "$(colorRed '***************************************')"
        echo "$(colorRed '* DANGER        DANGER                 DANGER        *')"
        echo "$(colorRed '***************************************')"
        echo "1) This script will PERMANENTLY change the configuration and overwrite configuration files"
        echo "2) This script requires a fresh install of Ubuntu or a server provisioned by Laravel Forge"
        echo ""
        echo "-> There is NO option to restore the changed config/files!"
        echo "-> Continue at your own risk."
        echo ""
}

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

#*****************************************************************
# HELP PAGE 
#*****************************************************************
function usage() {
  echo "Usage: "$0" [options]"
  echo ""
  echo "Options:"
  echo ""
  echo " -f     Run post-forge configuration"
  echo " -h     This help page"
  echo ""
  echo "Long options:"
  echo ""
  echo " --dry   Do a dry run without changing data"
  echo " --loglevel possible values: trace, debug, info, notice, warning, error, fatal"
  echo " For example 'ubstage.sh --warning'"
  echo ""
}

#*****************************************************************
# COMMAND LINE OPTIONS
#*****************************************************************

echo "Received commandline arguments ($#): $@"

if [ "$#" -gt 0 ]; then
    options=$(getopt -o 'fhuv' --long 'dry,trace,debug,info,notice,warning,error,fatal' -n "$(basename "$0")" -- "$@") || {
        echo "Error parsing options" >&2
        exit 1
    }
    
    eval set -- "$options"
fi

unset options

# Process the parsed options and arguments
while [ "$#" -gt 0 ]; do
   case "$1" in
       '-f')
          stage_type=forge
          shift
          continue 
       ;;
       '-h')
           usage
           exit 1
       ;;
       '-u')
          stage_type=ubuntu
          shift
          continue 
       ;;
       '-v')
          checkVersion
          exit 1
       ;;
       '--')
           shift
           break
       ;;
       '--dry')
           dry_run="true"
           shift
           continue
       ;;
       '--trace')
           user_log_level="trace"
           shift
           continue
       ;;
       '--debug')
           user_log_level="debug"
           shift
           continue
       ;;
       '--info')
           user_log_level="info"
           shift
           continue
       ;;
       '--notice')
           user_log_level="notice"
           shift
           continue
       ;;
       '--warning')
           user_log_level="warning"
           shift
           continue
       ;;
       '--error')
           user_log_level="error"
           shift
           continue
       ;;
       '--fatal')
           user_log_level="fatal"
           shift
           continue
       ;;
      *)
       echo 'No valid options or arguments supplied. Ignoring all options and using default configuration' >&2
       break
      ;;
   esac
done

#************************************************************************
#
# LARAVEL FORGE FUNCTIONS
#
#************************************************************************

# ----------------------------------------------
# set hostname
function setHostname() {

  # Logging
  log debug "-- Started function ${FUNCNAME[0]} "
  sectionHeader "${FUNCNAME[0]}"

  # Ask user for hostname
  # Show current hostname
        if [ -x "$(command -v hostnamectl)" ]; then
        log info "-- Current hostname: $(hostnamectl hostname)"
                read -p "Enter the new hostname: " answer

                if [[ "$answer" =~ ^[a-z0-9_-]+$ ]]; then
                        if [[ "$answer" != $(hostnamectl hostname) ]]; then
                                #valid hostname
                                log info "-- Setting hostname to $answer"
                                dryRun hostnamectl set-hostname "$answer"
                                log info "-- Adding new hostname to /etc/hosts"
                                # Update 127.0.0.1 line
                                dryRun sed -i "s/^127.0.0.1.*/127.0.0.1 $answer.localdomain $answer localhost/" /etc/hosts
                                # Update ::1 line (optional but recommended for IPv6 consistency)
                                dryRun sed -i "s/^::1.*/::1 $answer.localdomain $answer ip6-localhost ip6-loopback/" /etc/hosts
                        else
                                log warning "-- New and current hostnames are the same. Not changing it"
                        fi
                else
                        log warning "-- The hostname contains invalid characters or spaces. The hostname will not be set"
                fi

        else
                log warning "-- hostnamectl command not found. Cannot set the hostname"
        fi

} # END of function

#************************************************************************
#
# MAIN APPLICATION START
#
# Required script functions are already executed
#************************************************************************

# TRACING info
log trace "Initialising application. Setting up paths"
log trace "Script paths has been set to"
log trace "Current path: $current_path"
log trace "Script name: $script_name"
log trace "Script path: $script_path"
log trace "Script env path: $script_env_path"
log trace "Self path: $self_path"




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


set +x
# END of startmain=1 
