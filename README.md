# ANNODE Installation Script

This Bash script simplifies the setup of an ANNODE on Debian or RHEL-based Linux systems.

It installs dependencies, configures MariaDB, restores the latest database snapshot, deploys the node software, and sets up a systemd service (for non-desktop environments).

## Prequisities

**Root Access:** Run the script with sudo or as root user.

**Supported Distributions:** Debian-based or RHEL-based (tested on Debian 11 & 12, Ubuntu 20 & 22, Rocky Linux 8 & 9, AlmaLinux 8 & 9).

**ANNE Account:** You need a Neuron ID (NID) and Secret (SEED).
Generate your keys at https://www.anne.network/aon.html if you don’t have them.

## Installation: 

Download the Script:
`wget https://raw.githubusercontent.com/annemedia/annode-install/main/annode-install.sh`  

### Run the Script:

**WARNING:**

**DO NOT RUN THIS SCRIPT IF YOU HAVE EXISTING MARIADB DATABASES YOU CAN'T LOSE. If MariaDB is already installed, you’ll be prompted to purge it (losing existing databases) or abort.**

`sudo bash annode-install.sh your-nid your-seed [lite]`

- your-nid: Your ANNE Neuron ID (nid) (required)
- your-seed: Your ANNE Secret (seed) (required)
- lite: Optional boolean flag to run annode in lite (spectator) mode (disables mempool and graph cleaning).

#### Examples:  
##### Standard mainnet annode:
`sudo bash annode-install.sh mynodeid mysecret`

##### Lite mode mainnet annode:
`sudo bash annode-install.sh mynid mysecret 1`

## What the Script Does:

**Checks Permissions:** Ensures root access.

**Validates Input:** Confirms NID and SEED are provided.

**Installs Dependencies:** Updates the system, installs Java 17, MariaDB 10.5+, and needed tools - wget, curl, and unzip.

**Configures MariaDB:** Sets up the annedb database with a root user and anneroot user, both with random passwords; restores the latest snapshot from https://anne.network.

**Deploys the Node:** Downloads and configures the ANNE node in $HOME/annode, using your NID and SEED.

**Sets Up Service:** Creates a systemd service (annode.service) for automatic startup in non-desktop environments.

**Configures Firewall:** Opens port 9115 if csf, firewalld, or ufw is installed.

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

## Troubleshooting:

**Unsupported Systems:** If your distribution isn’t Debian or RHEL-based, the script exits with manual install instructions.

**MariaDB Conflicts:** If MariaDB is already installed, you’ll be prompted to purge it (losing existing databases) or abort.

**Port Issues:** Ensure port 9115 or custom port (if you changed it) is open if using a custom firewall other than csf, uwf or firewalld; the script skips this if no supported firewall is detected.

### Important Notes:

**Password Info:** The script generates and displays MariaDB passwords at the end.

**You must note these down from the terminal output, as they’re not stored anywhere else.**

**Lite Mode:** It is also possible to run the annode in Lite mode (Spectator mode) with as little as: 1 CPU, 1GB RAM, 20GB HDD (Linux) - Use the lite flag for a lighter annode setup, reducing resource usage by disabling mempool and graph cleaning.

### Additional Info:
See full the annode documentation at https://www.anne.network/files
