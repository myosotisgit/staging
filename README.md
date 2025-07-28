# ubstage.sh
A bash script that installs and configures certain applications on a fresh Ubuntu (24.04) install or a system provisioned with Laravel Forge.
This script was called "postforge" previously as it was tailored to servers provisioned by Laravel Forge. But given its general purpose it was
renamed to ubstage.sh as it also installs/configures applications on general Ubuntu installs.

Usage: ubstage.sh -fuh --force --<loglevel>
 -f : will run the post-configuration for Forge provisioned servers
 -u : will run the post-configuration for Ubuntu servers
> use -h for the most recent parameters

## ***************************************
## WARNING
## ***************************************
* This script will PERMANENTLY change the configuration and overwrite configuration files
* This script requires a fresh install of Ubuntu or a server provisioned by Laravel Forge

# Changelog

# v1.0 - 28 Jul 2025
- First stable release of ubstage.sh.
