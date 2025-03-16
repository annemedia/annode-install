# ANNODE Installation Script

This Bash script simplifies and fully automates the setup of an ANNODE on Debian or RHEL-based Linux systems. Whether you are a novice, intermediate, or an expert Linux user, this script is for you. 

It installs dependencies, configures MariaDB, restores the latest database snapshot, deploys the node software, and sets up a systemd service (for non-GUI environments) or creates a bash script (for GUI environments) you can use to run your ANNODE.

## Prequisities

**Root Access:** Run the script with sudo or as root user.

**Supported Distributions:** Debian-based or RHEL-based (tested on Debian 11 & 12, Ubuntu 20 & 22, Rocky Linux 8 & 9, AlmaLinux 8 & 9).

**Onboarded ANNE Account:** You need a Neuron ID (NID) and Secret (SEED).
Generate your keys at https://www.anne.network/aon.html if you don’t have them.

**All ANNE accounts must be onboarded to be active.
The account must receive coins or win a SOLO block reward to be onboard.
To receive coins, the new account must provide the PUBKEY to the sender of coins.
The sender uses the PUBKEY to onboard the new account and register the new NID onchain.**

If you are new to ANNE and cannot self-onboard, message us with your NID & PUB on Telegram at https://t.me/anne_unplugged or contact ANNE Media at https://x.com/annemedia_web

## Installation: 

Download the Script:
`wget https://raw.githubusercontent.com/annemedia/annode-install/main/annode-install.sh`  

### Run the Script:

**WARNING:**

**DO NOT RUN THIS SCRIPT IF YOU HAVE EXISTING MARIADB DATABASES YOU CAN'T LOSE. If MariaDB is already installed, it will be reinstalled. Albeit, you’ll be prompted to purge it (losing existing databases) or abort.**

`sudo bash annode-install.sh your-nid your-seed [lite]`

- your-nid: Your ANNE Neuron ID (nid) (required)
- your-seed: Your ANNE Secret (seed) (required)
- lite: Optional boolean flag to run annode in lite (spectator) mode (disables mempool and graph cleaning).

#### Examples:  
##### Standard mainnet annode:
`sudo bash annode-install.sh mynid mysecret`

##### Lite mode mainnet annode:
`sudo bash annode-install.sh mynid mysecret 1`

## What the Script Does:

**Checks Permissions:** Ensures root access.

**Validates Input:** Confirms NID and SEED are provided.

**Installs Dependencies:** Updates the system, installs Java 17, MariaDB 10.5+, and needed tools - wget, curl, and unzip.

**Configures MariaDB:** Sets up the annedb database with a root user and anneroot user, both with random passwords; restores the latest snapshot from https://anne.network.

**Deploys the Node:** Downloads and configures the ANNE node in $HOME/annode, using your NID and SEED.

**Sets Up Service:** Creates a systemd service (annode.service) for automatic startup in non-desktop environments.

**Configures Firewall:** Opens port 9115 (or custom if you change the PORT variable at the top of the script) if csf, firewalld, or ufw is installed.

## Post-Installation:

After running the script, you’ll see terminal output with important details:

**MariaDB Passwords:** The root password and anneroot user password for the annedb database.

**Record these immediately—they are not saved elsewhere and are needed for database access.**

### Starting the annode:

**Headless environment:** The annode is enabled to start on boot via systemd service automatically.

##### To start annode run:

`sudo systemctl start annode.service`

##### Check its status:

`systemctl status annode.service`

For GUI mode, edit /usr/bin/annode.sh, remove the --headless flag, and restart:

`sudo systemctl restart annode.service`

**GUI environment:** Start manually from terminal

`annode.sh`

For headless mode, edit /usr/bin/annode.sh and add the --headless flag before running.

**Debug Log:**

Check $HOME/annode/annode.log with:

`nano $HOME/annode/annode.log`

or

`tail -f $HOME/annode/annode.log`

# ANNODE Upgrade Script

### Basic Upgrade:
`wget https://raw.githubusercontent.com/annemedia/annode-install/main/annode-upgrade.sh`

`sudo bash annode-upgrade.sh`

### Upgrade with Database Restore:

Use your root password from the install output:

`sudo bash annode-upgrade.sh restore '<your-root-password>'  `

# Troubleshooting:

**Unsupported Systems:** If your distribution isn’t Debian or RHEL-based, the script exits with manual install instructions.

**MariaDB Conflicts:** If MariaDB is already installed, you’ll be prompted to purge it (losing existing databases) or abort.

**Port Issues:** Ensure port 9115 or custom port (if you changed it) is open if using a custom firewall other than csf, uwf or firewalld; the script skips this if no supported firewall is detected.

### Important Notes:

**Password Info:** The script generates and displays MariaDB passwords at the end.

**You must note these down from the terminal output, as they’re not stored anywhere else.**

**Lite Mode:** It is also possible to run the annode in Lite mode (Spectator mode) with as little as: 1 CPU, 1GB RAM, 20GB HDD (Linux) - Use the lite flag for a lighter annode setup, reducing resource usage by disabling mempool and graph cleaning.

# Additional Info:
See the full annode documentation at https://www.anne.network/files

# Contribution & Collaboration:

The install script has a limitation if MariaDB is already installed and there are any existing databases present. On user confirmation, these databases would be lost. A pull request to the following specification will be accepted:

- If MariaDB is already installed and the version is 10.5+, prompt the user with three options.
  
    1) Purge & reinstall MariaDB
    2) Prompt for their MariaDB root password
    3) Abort
       
- Adjust the related code to facilitate this feature.

If you are a software developer and excited to work with ANNE technology, message us at https://t.me/anne_unplugged or contact ANNE Media at https://x.com/annemedia_web
  
# LICENSE

This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <https://unlicense.org>
