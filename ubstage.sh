#!/usr/bin/bash
#
# Ubuntu installation & configuration (staging) script for new installs or post forge.
#
# This script will install applications and configure them on a fresh Ubuntu OS
# Compatible with: Unbuntu 24.04 LTS
#

#*****************************************************************
# SCRIPT DEFAULT SETTINGS
# Override these settings in ubstage.conf
#
#*****************************************************************

# Script version
version="1.0";

# Run level
# Value: true (default) false
# Can be disabled using --force commandline argument
dry_run=true;

# Stage type
# which type of staging should be executed. Default is "ubuntu"
# Values: ubuntu, postforge
# Default: empty (ask user)
stage_type=""

# log level
# values: trace, debug, info, notice (verbose), warning, error, fatal
# default: warning
# Can be set with the log level argument
log_level="debug"

# Log route
# default set to 'screen'
# Do NOT change this value. Use ubstage.conf
log_route="screen"

# Default configuration filename
config_file="ubstage.conf"
config_file_example="ubstage.conf.example"
repo_ubstage_folder_name="tooling.git"

# SERVER CONFIG VARIABLES
# Do not use a trailing slash!
forge_user_dir="/home/forge"

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
coloryellow='\e[1;33m'
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
    echo "Fatal: This script must be executed with root privileges."
    exit 1
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
    script_env_path=`command -v ubstage.sh`

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

#----------------------------------------------------------
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

#----------------------------------------------------------
# Function areYouSure
function areYouSure() {
	if [[ -z "$1" ]]; then
		local prompt="Are you sure you want to continue (Y/N): "
	else
		local prompt="$1"
	fi

    	read -p "$prompt" answer
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
       exit 1;
   fi

   # Is log level set by user (via command line) ?
   if [[ -n "$user_log_level" ]]; then
       log_level="$user_log_level"
   fi

    # Check if level exists
    # See https://stackoverflow.com/q/48086633 for the magic
    # not sure how the 'return 1 and return 2' actually work
    [[ ${logLevels[$log_level_arg]} ]] || return 1

    #check if level is enough
    (( ${logLevels[$log_level_arg]} < ${logLevels[$log_level]} )) && return 2

    #log here
    local logcolor=${logColors[$log_level_arg]}
    if [[ "$log_route_local" == "file" && "$log_file_name_path" ]]; then
      echo -e $logcolor"${log_level_arg}: ${log_message}"${logColors["reset"]} >>"$log_file_name_path"
    else
      echo -e $logcolor"${log_level_arg}: ${log_message}"${logColors["reset"]} >&2
    fi

    # Exit app when log level is 'error' or 'fatal'
    if [[ "$log_level_arg" == "error" || "$log_level_arg" == "fatal" ]]; then
      if [[ "$log_route_local" == "file" ]]; then
         echo -e $logcolor"${log_level_arg} error occured. Exiting program..."${logColors["reset"]} >>"$log_file_name_path"
      else
         echo -e $logcolor"${log_level_arg} error occured. Exiting program..."${logColors["reset"]} >&2
      fi
      exit 1
    fi


} # END of function

# ----------------------------------------------
# Function
# 
function readConfigFile() {
# Reading config file
if [[ -r "$script_path/$config_file" ]]; then
    # Found config file
    log notice "-- Found readable config file in ($script_path/$config_file). Importing..."

# ----------------------------------------------
    # import the config file
    source "$script_path/$config_file";

# ----------------------------------------------
    # Check for default values in config file (user did not add customizations)
    if [[ "$ubstage_path" =~ "_DEFAULT" ]]; then
      # User did not change default values. exit
      log warning "The ubstage_path has not been set in $config_file"
      log error "-> Add your configuration values to $config_file and try again..."
      exit 0
    fi

# ----------------------------------------------
    # Check for ubstage repo folder name default
    if [[ "$repo_ubstage_folder_name" =~ "_DEFAULT" ]]; then
      # User did not change default values. exit
      log warning "The repo_ubstage_folder_name has not been set in $config_file"
      log error "-> Add your custom values to  $config_file and restart..."
      exit 0
    fi
    if [[ "$repo_ubstage_folder_name" == "FOLDER_NAME_POSTFORGE_REPO" ]]; then
      # User did not change default values. exit
      echo -e $red"Error: Default value found for variable 'repo_ubstage_folder_name' in the config file!$colorclear";
      echo -e $yellow"Info:$colorclear Add your custom value to $config_file and restart..."
      exit 0
  else
      # Check if user, accidentally, added a path and name
      if [[ "$repo_ubstage_folder_name" == *\/* ]] || [[ "$repo_ubstage_folder_name" == *\\* ]]; then
         echo -e $red"Error: The config value contains a path instead of just the folder name!$colorclear";
         echo -e $yellow"Info:$colorclear Remove the path from the folder name."
         exit 0
      fi

    fi

  # ----------------------------------------------
  # Check if Path to Git Repos exists
  if [[ -r "$reposPath" && -d "$reposPath" ]]; then
     if [[ verbose == "true" ]]; then
         echo "-- Path to git repositories ($reposPath) is found and is readable"
     fi
  else
     echo -e ${logColors["fatal"]}"Fatal: Git repos folder not found at $reposPath"${logColors["reset"]}
     echo -e ${logColors["notice"]}"Add the correct path to the ubstage repository..."${logColors["reset"]}
     exit 0
  fi

 # Config file was not found ----------------------------------
else
    if [[ -e "$script_path/$config_file_example" ]]; then
      echo -e $red"Fatal: Config file ($config_file) not found in $script_path$colorclear";
      echo -e $yellow"Info:$colorclear Rename or copy the example config file to $config_file, add your configuration values and try again..."
      exit 0
    else
      echo -e $red"Fatal: Example Config file ($config_file_example) not found in $script_path$colorclear";
      echo -e $yellow"Info:$colorclear Reinstall the script and example config file";
      exit 0
    fi

fi # END of reading config file check
} # END of function

# Execute required function
readConfigFile

#----------------------------------------------------------
# Version check
# Check if the version of ubstage.sh and ubstage.conf match
# Run version check if requested by user
function checkVersion() {
 # Logging
    log debug "-- Started function ${FUNCNAME[0]} "

      echo "-- Running version check"
      log debug "Running version check for script and config"
      log debug "Checking if script and config version are matching";
      if [[ "$version" == "$config_version" ]]; then
         #  Versions are matching
      echo "Script version: $version"
      echo "Config version: $config_version"
         log notice "-- Config version and application version are matching";
      else
         log warning "The ubstage.sh ($version) and ubstage.conf ($config_version) version are not matching!";
         log fatal "-> Update ubstage.sh and ubstage.conf to the latest release."
         exit 0
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

#----------------------------------------------------------------
# addLinesToFile()
# Function that adds lines to a config file

addLinesToFile() {

    # Logging
    log debug "-- Started function ${FUNCNAME[0]} "

    local file="$1"
    # Ensure the file exists
    touch "$file"
    local content="$2"
    local missing_lines=()

    while IFS= read -r line; do
        grep -qF -- "$line" "$file" || missing_lines+=("$line")
    done <<< "$content"

    if [[ ${#missing_lines[@]} -gt 0 ]]; then
        printf "%s\n" "${missing_lines[@]}" | tee -a "$file" > /dev/null
    fi
}

#----------------------------------------------------------------
# ReplaceFileIfExists()
# Function to replace a file if it exists
function replaceFileIfExists() {
 # Logging
    log debug "-- Started function ${FUNCNAME[0]} "

    local source_file="$1"
    local target_file="$2"
    log debug "Source: $source_file"
    log debug "Target: $target_file"

    if [[ ! -e "$source_file" ]]; then
	    log fatal "Source file $source_file is not available"
    else
	log debug "Found source file: $source_file"
    fi
    if [[ -e "$target_file" ]]; then
        log info "Replacing $target_file with $source_file..."
        cp -f "$source_file" "$target_file"
        log info "Replacing $target_file is complete."
    else
	log debug "Target file: $target_file not found. Not replacing it"
        log warn "Target file $target_file does not exist. No action taken."
    fi
} # END of function


#----------------------------------------------------------------
# Add new file if not existing
function addFileIfNotExists() {
 # Logging
    log debug "-- Started function ${FUNCNAME[0]} "

    local source_file="$1"
    local target_file="$2"
    if [[ ! -f "$target_file" ]]; then
            log info "Adding $source_file to target $target_file"
            cp -f "$source_file" "$target_file"
    else
        log warn "Target file $target_file already exists. No action taken."
    fi

} # END of function

# ----------------------------------------------
# Dry run function
#  This function is used to execute commands in dry-run mode.
#  It will print or run the command
#  If dry_run is true, it will only print the command.
 
#  Usage: dryRun <command> [arguments...]
 
#  Example 1: Your original command with a pipe.
# We pass the full command and its parts as separate arguments.
# This is the correct way to handle commands with pipes.
# run_cmd bash -c "echo '0 3 * * * root /usr/bin/rkhunter --check --sk --report-warnings-only | mail -s 'rkhunter Security Scan Report' $email' | sudo tee /etc/cron.d/rkhunter_scan"

# Example 2: A simple command.
# run_cmd cp -v /path/to/source /path/to/destination

# Example 3: A command with redirects.
# run_cmd find . -name "*.log" -exec rm {} \;

# Example 4: A command that needs root privileges.
# run_cmd sudo systemctl restart nginx.service

function dryRun() {
    # If in dry-run mode, just print the command.
    if [ "$dry_run" = "true" ]; then
        echo "-- Dry run mode enabled: The following command would be executed:"
        printf "  %s\n" "$*"
    else
        # Otherwise, execute the command.
        # This uses "$@" to expand the arguments correctly.
	echo "Executing command(s)..."
        "$@"
    fi
} # END of function

# ----------------------------------------------
# Show the intro header when starting script

function showIntro() {
        # Logging
        log debug "Started function ${FUNCNAME[0]} "

        echo "$(colorYellow '----------------------------------------------')"
        echo "$(colorYellow ' Ubuntu staging script')"
        echo "$(colorYellow ' Version: ')$version";
        echo "$(colorYellow ' Staging type: ')$stage_type";
        echo "$(colorYellow ' Description:')";
        echo " UBstage can stage a fresh Ubuntu OS and runs post-configuration scripts to improve the configuration and security of Forge installed servers";
        echo "$(colorYellow '----------------------------------------------')"
        echo ""
        echo "$(colorRed '***************************************')"
        echo "$(colorRed '* DANGER        DANGER                 DANGER        *')"
        if [ $dry_run = false ]; then 
                echo "$(colorRed '* Dry run mode is disabled!! Changes will be permanent!')" 
        fi;
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
        echo " $header_title"
        echo "$(colorYellow '----------------------------------------------')"

} # END of function 

# ----------------------------------------------
# function stageType
# Ask user to set the stage type when not set through commandline
function stageType() {
        # Logging
        log debug "Started function ${FUNCNAME[0]} "

	if [[ -z "$stage_type" ]]; then
		# Stage Type was not set
		echo "Warning: The stage type (forge/ubuntu) was not set on the commandline. Choose the stage type before continuing"
	
		read -p "Choose stage type (forge/ubuntu): " answer
   		case $answer in
      			forge)
          		echo "Setting stage type to forge."
			stage_type="forge"
        		 ;;
     			ubuntu)
          		echo "Setting stage type to ubuntu."
			stage_type="ubuntu"
         		;;
     			* )
         		echo "Incorrect choice. Try again."
         		exit 1
         		;;
   		esac
	fi	

} # END of function


#*****************************************************************
# HELP PAGE 
#*****************************************************************
function usage() {
  echo "Usage: "$0" [options]"
  echo "Remark: Dry run mode is enabled by default. To override use --force"
  echo ""
  echo "Options:"
  echo ""
  echo " -f     Run Laravel Forge post configuration"
  echo " -u     Run Ubuntu (24.04) post configuration"
  echo " -h     This help page"
  echo ""
  echo "Long options:"
  echo ""
  echo " --force   Disable dry run mode and make permanent changes!"
  echo " --loglevel possible values: trace, debug, info, notice, warning, error, fatal"
  echo " For example 'ubstage.sh --warning'"
        echo ""
}

#*****************************************************************
# COMMAND LINE OPTIONS
#*****************************************************************

#
options=$(getopt -o 'fhuv' --long 'dry,force,trace,debug,info,notice,warning,error,fatal' -n "$0" -- "$@")
if [ $? -ne 0 ]; then
    # if getopt returns a non-zero status there was an error
    usage
    exit 1
fi

# eval the options
eval set -- "$options"
unset options

# Process the parsed options and arguments
while true; do
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
	'--force')
	  dry_run="false"
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

log debug "Initialising application. Setting up paths"
log debug "Script paths has been set to"
log debug "Current path: $current_path"
log debug "Script name: $script_name"
log debug "Script path: $script_path"
log debug "Script env path: $script_env_path"
log debug "Self path: $self_path"



#************************************************************************
#
# LARAVEL FORGE FUNCTIONS
#
#************************************************************************

#------------------------------------------------
# Function
# Whitelist Laravel Forge IP's in the ufw firewall
function addFirewallRulesForge() {

sectionHeader "UFW Firewall rules for forge"

# Check if ufw is enabled
$(ufw status | grep -qw active)
if [ "$?" == 1 ]; then
        log info "ufw firewall is not active. Enable your firewall. Rulew will be added."
fi
# Adding firewall rules, even when ufw is disabled
for t in ${whitelistForgeIp[@]}; do
  log debug "Adding new firewall rule for $t"
        dryRun ufw allow from $t to any port 22 comment "Laravel Forge $t"
done

if sudo ufw status | grep -qE '^22/tcp\s+ALLOW\s+Anywhere'; then
    echo "Found Forge firewall rule for port 22 to any. Removing it for security purposes."
    dryRun sudo ufw delete allow 22/tcp
else
    echo "The default Forge firewall rule for port 22 was not found."
fi

# Remove IPv6 allow rule for port 22 (must use "v6" notation)
if sudo ufw status | grep -qE '^22/tcp \(v6\)\s+ALLOW\s+Anywhere \(v6\)'; then
    echo "Found Forge firewall rule for port 22 to any. Removing it for security purposes."
    dryRun sudo ufw delete allow 22/tcp
else
    echo "The default Forge firewall rula for port 22 was not found."
fi

} # END of function

#------------------------------------------------
# Function
# When Forge provisions a site, it is cloned using --single-branch option. This will tell git
# to restrict git to use the  "main/master" branch
# To allow branches, other then main, in the git config enable it
#------------------------------------------------
function customGitBranches() {
sectionHeader "Allow custom feature branches in git repos"

# Git main branch
log info "Enable custom branches"

# Find folder and add to array git_dirs
mapfile -t git_dirs < <(find "${forge_user_dir}" -name .git -type d -prune)

for d in "${git_dirs[@]}"; do
  echo "Processing directory: $d"
  cd "$d/.." || continue
  read -p "Do you want to allow custom branches? (Y/N): " answer </dev/tty

  case "$answer" in
    [yY]) 
      echo "info : Enabling custom branches in $d"
      echo "Executing: git config remote.origin.fetch refs/heads/*:refs/remotes/origin/*"
      dryRun git config remote.origin.fetch refs/heads/*:refs/remotes/origin/*
      ;;
    [nN]) 
      echo "Skipping $d"
      ;;
    *) 
      echo "Invalid input, skipping."
      ;;
  esac

  echo "Moving to next directory..."
done
} # END of function

#************************************************************************
#
# UBUNTU FUNCTIONS
#
#************************************************************************

#-----------------------------------------------
# Function
# Limit the journal logs to a maximum size
function setMaxSizeJournal() {
	# Logging
  log debug "-- Started function ${FUNCNAME[0]} "
  sectionHeader "${FUNCNAME[0]}"
    dryRun journalctl --vacuum-size=2G
}

#-----------------------------------------------
# Function
# Silence the Message of the Day
function hushMotd() {
sectionHeader "Hush hush little MOTD"
# Disabling motd messages on login
hushed=0
if [ ! -f /root/.hushlogin ]; then
	log debug "Did not find /root/.hushlogin. Adding it"
        log info "Disabling message o/t day for root"
        dryRun touch /root/.hushlogin
else
	log debug "Found /root/.hushlogin. Motd is already hushed"
fi
if [ -d "$forge_user_dir" ] && [ ! -f "$forge_user_dir/.hushlogin" ]; then
        log info "Disabling message o/t day for $forge_user_dir"
        dryRun touch $forge_user_dir/.hushlogin
else
	log debug "Found hushlogin in $forge_user_dir. Motd is already hushed"
fi

} # END of function

#-----------------------------------------------
# Function
# Extending auto-upgrades configuration
#
function configUnattendedUpgrades() {

sectionHeader "Installing and configuring unattended upgrades"

if ! isPackageInstalled "unattended-upgrades"; then
	log warning "Unattended-upgrades is not installed. Installing it..."
	dryRun apt install -y unattended-upgrades 
fi
log info "Unattended-upgradess is installed. Configuring it."

# Overwriting 10Periodic with own config
# Forge also uses this mechanism
SOURCE_FILE="${current_path}/assets/10periodic"         # Your version in assets/
TARGET_FILE="/etc/apt/apt.conf.d/10periodic"  # File to check and replace
# Call the function
dryRun replaceFileIfExists "$SOURCE_FILE" "$TARGET_FILE"

# Overwriting 10Periodic with own config
# Forge also uses this mechanism
SOURCE_FILE="${current_path}/assets/20auto-upgrades"         # Your version in assets/
TARGET_FILE="/etc/apt/apt.conf.d/20auto-upgrades"  # File to check and replace
# Call the function
dryRun replaceFileIfExists "$SOURCE_FILE" "$TARGET_FILE"

# Overwriting 50unattended-upgrades with own config
# Forge also uses this mechanism
# Define file paths
SOURCE_FILE="${current_path}/assets/50unattended-upgrades"         # Your version in assets/
TARGET_FILE="/etc/apt/apt.conf.d/50unattended-upgrades"  # File to check and replace
# Call the function
dryRun replaceFileIfExists "$SOURCE_FILE" "$TARGET_FILE"

# Check if unattended upgrades are working
log info "Checking if Unattended-upgrades are working. Dry-run. Check the input"
sudo unattended-upgrades --dry-run --verbose

} # END of function


#-----------------------------------------------
# Function
#
# Checks the effective sshd configuration and applies a hardening configuration if needed.
#
function hardenSSH() {
    sectionHeader "Hardening SSH"

    # Define required values and use local variables to avoid polluting the global scope
    local req_password_auth="no"
    local req_banner="none"
    local -A ssh_config # Use an associative array to store config values

    # --- Step 1: Efficiently get all config values at once ---
    # Run sshd -G once and parse its output into an associative array.
    # This is far more efficient than running it multiple times.
    while read -r key value _; do
        # sshd -G outputs keys in lowercase
        ssh_config["$key"]="$value"
    done < <(sshd -G 2>/dev/null) # Redirect stderr to hide potential warnings

    # For debugging, show the values we found
    log debug "Effective SSH Config: PasswordAuthentication=${ssh_config[passwordauthentication]}, PermitRootLogin=${ssh_config[permitrootlogin]}, Banner=${ssh_config[banner]}"

    # --- Step 2: Check if SSH is already hardened using a guard clause ---
    # This makes the logic cleaner. If it's already compliant, we just say so and exit.
    local permit_root_ok=false

    if [[ "$stage_type" == "ubuntu" ]]; then
     # For Ubuntu, be strict: only "no" is acceptable.
     log debug "Ubuntu stage: Verifying PermitRootLogin is strictly 'no'."
     if [[ "${ssh_config[permitrootlogin]}" == "no" ]]; then
        permit_root_ok=true
     fi
    else
     # For other stages, use the broader set of secure values.
     log debug "Non-Ubuntu stage: Verifying PermitRootLogin against multiple secure values."
     case "${ssh_config[permitrootlogin]}" in
        no|prohibit-password|without-password|forced-commands)
            permit_root_ok=true
            ;;
     esac
    fi

    if [[ "${ssh_config[passwordauthentication]}" == "$req_password_auth" && \
          "$permit_root_ok" == true && \
          "${ssh_config[banner]}" == "$req_banner" ]]; then
        log info "SSH is already hardened."
        return 0 # Success, no changes needed
    fi

    # --- Step 3: If not hardened, apply the new configuration ---
    log info "SSH is not hardened. Applying new configuration."

    # Ensure the config drop-in directory exists. Using -p is safer.
    if [[ ! -d "/etc/ssh/sshd_config.d" ]]; then
	log debug "SSH config dir /etc/ssh/sshd_config.d does not exists. Creating it"
    	dryRun mkdir -p /etc/ssh/sshd_config.d
    else
	log debug "SSH config dir /etc/ssh/sshd_config.d exists. Config files can be added there"
    fi

    # Define source and target file paths
    local source_file="${current_path}/assets/90ubstage-$stage_type"
    local target_file="/etc/ssh/sshd_config.d/90ubstage-$stage_type"

    # Add the file and restart the service
    dryRun addFileIfNotExists "$source_file" "$target_file"
    log info "Added new SSH config. Restarting SSH service..."

    # Use systemctl if available; otherwise, fall back to the older 'service' command.
    # Also, the service is often named 'sshd' on systemd systems.
    if command -v systemctl &>/dev/null; then
        dryRun systemctl restart sshd
    else
        dryRun service ssh restart
    fi

} # END of function

# ----------------------------------------------
# set hostname
function setHostname() {

  # Logging
  log debug "-- Started function ${FUNCNAME[0]} "
  sectionHeader "${FUNCNAME[0]}"

  local change_hostname=false

  # Ask user for hostname
  # Show current hostname
        if [ -x "$(command -v hostnamectl)" ]; then
        log info "-- Current hostname: $(hostnamectl hostname)"
		colorRed "Warning: Forge sets the hostname when provisioning the server. It is not recommended to change the hostname using this script with Forge servers"
		read -p "Do you want to set a new hostname: (Y/N): " answer
		case $answer in
      			[yY] )
          		echo "You want to change the hostname..."
			change_hostname=true
         		;;
     			[nN] )
         		echo "Not changing the hostname"
         		;;
     			* )
         		echo "Incorrect choice. Choose Y/N next time... "
         		exit 1
         		;;
   		esac

	if [[ "$change_hostname" == true ]]; then
		read -p "Enter the new hostname (without spaces and special characters!): " answer
		if [[ "$answer" =~ ^[a-zA-Z0-9_-]+$ ]]; then
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
	fi # END of change_hostname check

        else
                log warning "-- hostnamectl command not found. Cannot set the hostname"
        fi # END of hostnamectl check

} # END of function

# ----------------------------------------------
# Set server timezone
function setTimezone() {
    log debug "-- Started function ${FUNCNAME[0]}"
    sectionHeader "Set Timezone"

    if ! command -v timedatectl &> /dev/null; then
        log warning "The timedatectl command is not available. Cannot set the timezone."
        return 1
    fi

    # Loop 1: Ask for confirmation to continue
    while true; do
        log warning "It is strongly recommended to set the server timezone in Forge. Are you sure you want to continue?"
        read -p "Continue? (Y/N): " answer
        case "$answer" in
            [yY])
                echo "Continuing..."
                break # Exit the confirmation loop
                ;;
            [nN])
                echo "Aborting timezone change..."
                log debug "-- Aborted function ${FUNCNAME[0]}"
                return 0 # Exit the function
                ;;
            *)
                echo "Incorrect choice. Please choose Y or N."
                ;;
        esac
    done

    log info "-- Current timezone: $(timedatectl show --property=Timezone --value)"

    local TIMEZONE
    # Loop 2: Ask for a valid timezone
    while true; do
        read -p "Enter the new timezone (e.g., Europe/London): " TIMEZONE

        # Check if the entered timezone is a valid one
        if timedatectl list-timezones | grep -q "^$TIMEZONE$"; then
            log info "Valid timezone '$TIMEZONE' entered."
            break # Exit the timezone validation loop
        fi

        # Try to suggest a timezone if user entered a partial name
        SUGGESTION=$(timedatectl list-timezones | grep -i "/$TIMEZONE$" | head -n 1)
        if [[ -n "$SUGGESTION" ]]; then
            echo "Invalid timezone '$TIMEZONE'. Did you mean: '$SUGGESTION'?"
        else
            echo "Invalid timezone. Please check available timezones using: 'timedatectl list-timezones'"
        fi
    done

    # Final confirmation before making changes
    read -p "Are you sure you want to set the timezone to '$TIMEZONE'? (Y/N): " final_answer
    if [[ "$final_answer" =~ ^[Yy]$ ]]; then
        # Set the timezone using timedatectl
        dryRun timedatectl set-timezone "$TIMEZONE"

        # Manually update /etc/timezone
        dryRun bash -c "echo \"$TIMEZONE\" | sudo tee /etc/timezone > /dev/null"

        log warning "-- Updating the timezone will NOT update the timezone on Laravel Forge dashboard"
        log warning "-- Laravel forge does NOT adjust /etc/timezone!"
        log info "-- Timezone successfully updated to $TIMEZONE."
    else
        echo "Aborting timezone change..."
    fi

}

# ----------------------------------------------
# Install NTPsec
# See also: https://docs.ntpsec.org/latest/ntpsec.html

function installNtpsec() {

  # Logging
  log debug "-- Started function ${FUNCNAME[0]} "
  sectionHeader "${FUNCNAME[0]}"

	# install ntp
	log info "Checking for older version of ntp/ntpsec..."
	if dpkg -l | grep -q "ntp"; then
		echo ""
		log info "Found older version of ntp/ntpsec. Removing"
		echo ""
		dryRun apt remove --purge -y ntp
		dryRun apt remove --purge -y ntpsec
		dryRun apt autoremove -y
	fi

	echo ""
	log info "Installing ntpsec"
	echo ""
	dryRun apt update & dryRun apt install ntpsec -y

	# Check if install was correct
	if [[ "$dry_run" == "true" ]]; then
		echo "Dry mode enabled. NTP was not installed. Skipping install checks"
	else
  		if ! command -v ntpq &> /dev/null; then
        		log warning "NTP was not installed or the installation failed"
        	return 1
  		fi
	fi
	# Enable and start NTPsec service
	echo ""
	log info "Enabling ntpsec to run at system start"
    dryRun systemctl enable ntpsec
    dryRun systemctl start ntpsec

    # Check if NTPsec is running
    if systemctl is-active --quiet ntpsec; then
	echo ""
        log info "NTPsec service is running."
    else
	echo ""
        log warning "NTPsec is not running! Check the install log and configuration"
        return 1
    fi

    # Add firewall rule for NTP (UDP 123)
	echo ""
    echo "Allowing NTP through the firewall..."
    dryRun ufw allow 123/udp comment 'ntp traffic'
		
		echo ""
    log info "NTPsec installation and setup complete."
		echo ""

} # END of function

#-----------------------------------------------
# Function
# Install and configure RKHunter rootkit checker
function ubuntuApps() {

  # Logging
  log debug "-- Started function ${FUNCNAME[0]} "
  sectionHeader "${FUNCNAME[0]}"

  log info "Installing common Ubuntu apps"
 dryRun app install -y vim nano software-properties-common

} # END of function


#-----------------------------------------------
# Function
# Install and configure RKHunter rootkit checker
function setupRkhunter() {

sectionHeader "Rkhunter Check root kit"

    local email="$1"

    # Check if rkhunter is installed
		if ! command -v rkhunter &>/dev/null; then
        log info "Installing rkhunter..."
        dryRun sudo DEBIAN_FRONTEND=noninteractive apt-get install -y rkhunter 
        log info "Installing mailutils..."
        dryRun sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mailutils
    else
        log info "rkhunter is already installed. Configuring it"
    fi
		
	 if grep -q "^MAIL-ON-WARNING" /etc/rkhunter.conf; then
        dryRun sudo sed -i "s/^MAIL-ON-WARNING=.*/MAIL-ON-WARNING=\"$email\"/" /etc/rkhunter.conf
    else
        dryRun bash -c "echo \"MAIL-ON-WARNING=\"$email\"\" | sudo tee -a /etc/rkhunter.conf"
    fi

    log info "Setting up daily scan"
    dryRun bash -c "echo \"0 3 * * * root /usr/bin/rkhunter --check --sk --report-warnings-only | mail -s 'rkhunter Security Scan Report' $email\" | sudo tee /etc/cron.d/rkhunter_scan"

# Function to create daily update cron job
    log info "Setting up daily updates"
    dryRun bash -c "echo \"0 2 * * * root /usr/bin/rkhunter --update && /usr/bin/rkhunter --propupd\" | sudo tee /etc/cron.d/rkhunter_update"

# Function to run initial update and scan
    log info "Updating rkhunter and running initial scan..."
    dryRun sudo rkhunter --update
    dryRun sudo rkhunter --propupd
    
    read -p "You want to run a full rootkit scan (about 4 minutes)? (Y/N)" answer
   case $answer in
      [yY] )
	      log info "Running RKhunster full rootkit check"
    	rkhunter --check --sk
         ;;
     [nN] )
         echo "Skipping full rootkit check"
         ;;
     * )
         echo "Incorrect choice. SKipping full rootkit check... "
         exit 1
         ;;
   esac

	log info "Rkhunter rootkit checker installed and configured."
	log info "Cron script installed for updating and regular rootkit check. See /etc/cron.d"
} # END of function

#-----------------------------------------------
# Function
# Install and configure Lynis system checker
# See Lynis doc for most recent install procedure
# https://packages.cisofy.com/community/#debian-ubuntu
function setupLynis() {

# Logging
  log debug "-- Started function ${FUNCNAME[0]} "
  sectionHeader "Lynis System and rootkit checker"

# Check if keyrings folder exists, if not create
if [[ -d /usr/share/keyrings ]]; then
	log info "Lynis: /usr/share/keyrings folder exists"
else 
	log warn "Lynis: /usr/share/keyrings folder does not exist. creating it"
	dryRun mkdir -p /usr/share/keyrings
	log debug "Lynis: Directory /usr/share/keyrings created"
fi

dryRun bash -c "curl -fsSL https://packages.cisofy.com/keys/cisofy-software-public.key \
  | sudo gpg --dearmor -o /usr/share/keyrings/cisofy-archive-keyring.gpg"

dryRun bash -c "echo \"deb [signed-by=/usr/share/keyrings/cisofy-archive-keyring.gpg] https://packages.cisofy.com/community/lynis/deb stable main\" | sudo tee /etc/apt/sources.list.d/cisofy-lynis.list"

dryRun apt install apt-transport-https
dryRun bash -c "echo 'Acquire::Languages \"none\";' | sudo tee /etc/apt/apt.conf.d/99disable-translations"
dryRun apt update
dryRun apt install lynis
log info "Lynis is installed. Checking version"
dryRun lynis show version
    read -p "You want to run a full Lynis scan (about 2 minutes)? (Y/N)" answer
   case $answer in
      [yY] )
	      log info "Running Lynis audit scan"
	      log info "A typical Lynis end score is about 63"
    		lynis audit system
         ;;
     [nN] )
         echo "Skipping lynis scan"
         ;;
     * )
         echo "Incorrect choice. Skipping full lynis scan... "
         exit 1
         ;;
   esac

} # END of function

#-----------------------------------------------
# Function
# Install and configure Lynis system checker
# See Lynis doc for most recent install procedure
# https://packages.cisofy.com/community/#debian-ubuntu
function setupChkrootkit() {

# Logging
  log debug "-- Started function ${FUNCNAME[0]} "
  sectionHeader "Lynis System and rootkit checker"

  log info "Installing CHKRootKit. When prompted choose: Internet Site"
  log info "Postfix config option: Choose localhost"
  areYouSure "Continue installing chkrootkit (Y/N): "
  dryRun apt install -y dialog
  dryRun apt install -y chkrootkit

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
    areYouSure "Are you sure? (Y/N): "
    stageType

case $stage_type in
	forge)
		log info "Staging type is set to $stage_type"
		
		# Ubuntu business
		setTimezone # The hostname is set by Forge during provisioning
		setHostname 
        	hardenSSH 
		setMaxSizeJournal
        	configUnattendedUpgrades 
        	installNtpsec 
		hushMotd 
		ubuntuApps 
	
        	# Applications
        	setupRkhunter tech@myosotis-ict.nl 
		setupChkrootkit
        	setupLynis

		# forge business
		addFirewallRulesForge
		customGitBranches
        
	;;
	ubuntu)
		log info "Staging type is set to $stage_type (default)"
		setHostname 
		setTimezone 
		hardenSSH
        	hushMotd 
		configUnattendedUpgrades
        	setMaxSizeJournal
		installNtpsec 
		ubuntuApps 

        	# Applications
        	setupRkhunter tech@myosotis-ict.nl
		setupChkrootkit
		setupLynis
	;;
esac

sectionHeader "ubstage script has completed. Reboot the system"
}

# Start main function
main 

# END of startmain=1 
