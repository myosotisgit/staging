# ubstage.sh
A staging script for Ubuntu 22.04 and higher) and systems provisioned with Laravel Forge

Usage: ubstage.sh <OPTIONS>
> View the help page for all options

## ***************************************
## WARNING
## ***************************************
* This script will PERMANENTLY change the configuration and overwrite configuration files
* This script requires a fresh install of Ubuntu or a server provisioned by Laravel Forge

# Changelog

# v1.1 - 10 dec 2025
- Added new install blocks for Apache2, MySQL, PHP, Cerbot, Phpmyadmin
- Added new ubuntu blocks for chkrootkit, rkhunter and lynis.
- Fixed ssh jail for fail2ban block
- Improved file replace function
- Removed legacy code (checked with shellcheck)
- Added dependency install for ufw
- Improved ufw configuration
- Introduced two "Are you sure" functions with different logic 
- Added an interactive mode that can be disabled

# v1.0 - 28 Jul 2025
- First stable release of ubstage.sh.
