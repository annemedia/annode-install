#!/bin/bash
# ANNODE Installation Script - Developer Documentation
#
# Overview:
# This script automates the installation and configuration of an annode
# on Debian or RHEL-based Linux distributions. It handles dependency installation,
# MariaDB setup, database restoration, node software deployment, and systemd service
# configuration. The script is designed to run with root privileges and requires
# a Node ID (NID) and Secret (SEED) as arguments, with an optional lite mode flag (1)
#
# Usage:
#   sudo bash annode-install.sh <NID> <SECRET> [lite]
#   - <NID>: The ANNE Node ID (required)
#   - <SECRET>: The ANNE Secret (required)
#   - [lite]: Optional flag to enable lite mode (disables mempool)
#
# Script Flow:
# 1. Root Check: Ensures the script runs with root privileges.
# 2. Argument Validation: Verifies NID and SECRET are provided.
# 3. Package Manager Detection: Identifies apt, dnf, or yum; exits if unsupported.
# 4. Dependency Installation: Installs required tools and Java 17.
# 5. MariaDB Setup:
#    - Checks and upgrades MariaDB to 10.5+ if needed.
#    - Purges existing MariaDB if present (with user consent).
#    - Configures database and user with random passwords.
#    - Restores latest ANNE mainnet snapshot.
# 6. Node Deployment:
#    - Downloads and extracts the ANNE node software.
#    - Configures node.properties with NID, SECRET, and network settings.
# 7. Systemd Service: Sets up a service for non-desktop environments.
# 8. Firewall Configuration: Opens port 9115 if csf, firewalld, or ufw is present.
# 9. Final Instructions: Prints post-execution instructions (not shown here).
#
# Key Variables:
# - NID, SECRET, LITE: Command-line arguments.
# - DB_NAME: "annedb" - Mainnet database name.
# - DB_USER_NAME: "anneroot" - MariaDB user.
# - MIN_MARIA_VERSION: "10.5" - Minimum required MariaDB version.
# - PORT: "9115" - P2P port for the node (can be custom, change it if you wish)
# - PEERSLIST: Semicolon-separated list of bootstrap peers IPs
# - DB_USER_PASS, DB_ROOT_USER_PASS: Generated random passwords for MariaDB.
#
# Key Functions:
# - get_package_manager(): Detects the package manager (apt, dnf, yum).
# - install(): Installs a package if not present, exits on failure.
# - checkMariaCandidateVersion(): Ensures MariaDB version meets requirements.
# - is_java17_available(): Checks for Java 17 installation.
# - is_mysql_command_available(): Detects existing MySQL/MariaDB.
#
# Dependencies:
# - Supported package managers: apt, dnf, yum
# - Tools: sudo, coreutils, nano, unzip, wget, curl, dpkg/rpmdevtools (as needed)
# - Java 17 (openjdk-17-jdk or java-17-openjdk)
# - MariaDB Server 10.5+
#
# Important Developer Notes:
# - The script assumes network connectivity for downloads from anne.network.
# - No explicit error handling for failed downloads or database imports; relies on command exit codes.
# - The install() function has a redundant structure but is functional.
# - Firewall configuration skips silently if no supported firewall is found.
# - The WANIP detection logic supports both IPv4 and IPv6, wrapping IPv6 in brackets as needed by annode config.
#
# ***IMPORTANT NOTE FOR USERS AND DEVELOPERS***
# At the end of execution, the script prints critical instructions, including
# the generated MariaDB passwords for the root user (DB_ROOT_USER_PASS) and
# the 'anneroot' user (DB_USER_PASS). These are not stored elsewhere in this
# script and are essential for database access. Users MUST manually note these
# passwords from the terminal output.
#
# License: The Unlicense License.
#

export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
# Check if user is root
[ $(id -u) != "0" ] && { echo "Error: You must use sudo or be root to run this script"; exit 1; }

NID=$1
SECRET=$2
LITE=$3

if [ -z "$NID" ] || [ -z "$SECRET" ]; then
    echo "Error: You must provide NID and SEED in arguments of this script.";
    echo "Run: sudo bash annode-install.sh yournid yourseed";
    echo "if you don't have NID and SEED, generate new ANNE account at https://www.anne.network/aon.html";
    echo "Execution aborted";
    exit 2;
fi

DB_NAME="annedb"
DB_USER_NAME="anneroot"
MIN_MARIA_VERSION="10.5"
PORT="9115"

PEERSLIST="5.161.199.125:9115;107.174.14.144:9115;193.42.62.150:9115;65.109.89.77:9115;148.251.136.43:9772;116.203.230.116:9115;23.95.167.208:9115;"

# Detect PM
get_package_manager() {
  for manager in apt dnf yum; do
    if which $manager > /dev/null 2>&1; then
      echo $manager
      return
    fi
  done
    echo -e "\e[31mThis script is running on an unsupported distribution.
      Supported distributions are Debian or RHEL based. 
      You can still install annode manually. It runs anywhere Java runs.
      
      Dependencies:
      mariadb 10.5+
      unzip
      java jdk 17\e[0m
      
      See https://www.anne.network/files for further instructions."
    exit 3;
}

command=$(get_package_manager)

run="$command update -y && $command upgrade -y"
eval "$run"

install() {
    is_app_command_available() {
        which "$1" > /dev/null 2>&1
    }
    if ! is_app_command_available "$1"; then
        if [ "$1" == "sudo" ]; then
          $command install "$1" -y
        else 
          sudo $command install "$1" -y
        fi
        if [ $? -ne 0 ]; then
            echo -e "\e[31mInstallation failed for package: $1\e[0m"
            echo -e "\e[31mCheck Sources: Verify that your sources file includes the necessary repositories\e[0m"
            echo -e "\e[31mExecution aborted.\e[0m"
            exit 4
        fi
    fi
}
install "sudo"
install "coreutils"
install "nano"
install "unzip"
install "wget"
install "curl"
clear

## running update again, sometimes may take two rounds
eval "$run"
clear

DB_USER_PASS=$(sudo cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 21 | head -n 1);
DB_ROOT_USER_PASS="r00tXyZ$DB_USER_PASS";

checkMariaCandidateVersion () {
  versionltMIN=0
  if [ $command == "apt" ]; then
    install "dpkg"
    version=$(apt-cache policy mariadb-server | grep 'Candidate' | awk '{print $2}' | sed 's/^[0-9]*://; s/-.*//')
    if dpkg --compare-versions "$version" lt "$MIN_MARIA_VERSION"; then
      versionltMIN=1
    fi
  else
    install rpmdevtools
    version=$($command info mariadb-server | grep 'Version' | awk '{print $3}' | tail -n 1)
    result=$(rpmdev-vercmp "$version" "$MIN_MARIA_VERSION")
    if [[ $result == *"<"* ]]; then
      versionltMIN=1
    fi
  fi
  if [[ -z "$version" || ! "$version" =~ ^[0-9]+\.[0-9]+ ]]; then
      echo -e "\e[31mWARNING: Unable to retrieve MariaDB server installation candidate version\e[0m"
      echo -e "\e[31mThis script will continue but may not work correctly on your system. Watch for any errors and troubleshoot if necessary.\e[0m"
      echo -e "\e[31mMinimum required version of MariaDB server is 10.5. Do not run annode on lower mariadb versions.\e[0m"
      for i in {15..1}; do
          echo "Installation will resume in $i seconds."
          sleep 1
      done
  fi

  if [[ $versionltMIN -eq 1 ]]; then
      # echo "$MIN_MARIA_VERSION is greater than $version"
      echo -e "\e[31mWARNING: You are using this script on old version of OS that doesn't have MariaDB Server installation candidate greater than 10.5"
      echo -e "\e[31mMinimum required version of MariaDB server is 10.5. Do not run annode on lower mariadb versions.\e[0m"
      echo -e "\e[31mThe script will attempt to upgrade the candidate and install it.\e[0m"
      echo -e "\e[31mThis script will continue but might not work correctly on your system. Watch for any errors and troubleshoot if necessary.\e[0m"

      supported="# The MariaDB Repository only supports these distributions:
#    * RHEL/Rocky 8 & 9 (rhel)+
#    * RHEL/CentOS 7 (rhel)+
#    * Ubuntu 20.04 LTS (focal), 22.04 LTS (jammy), and 24.04 LTS (noble)+
#    * Debian 10 (buster), Debian 11 (bullseye), and Debian 12 (bookworm)+
#    * SLES 12 & 15 (sles)+"
      echo -e "\e[31m$supported\e[0m"

      for i in {15..1}; do
          echo "Installation will resume in $i seconds."
          sleep 1
      done
      install "ca-certificates"
      if [ $command == "apt" ]; then
        install "apt-transport-https"
      fi
      sudo curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash
  fi
}

checkMariaCandidateVersion

is_java17_available() {
  java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
  [[ $java_version == 17* ]]
}

is_mysql_command_available() {
  which mysql > /dev/null 2>&1
}

if ! is_java17_available; then
  run="openjdk-17-jdk"
  # sudo apt-get install openjdk-11-jre
  if [[ $command == "dnf" || $command == "yum" ]]; then
      run="java-17-openjdk"
  fi
  install $run
fi

if is_mysql_command_available; then
  read -p "Existing MySQL command found. For this script to work correctly 
  MariaDB has to be purged and reinstalled. Do you want to completely purge 
  the existing MariaDB installation? 
  THIS WILL REMOVE ANY EXISTING DATABASES AND CONFIGURATION (y/n): " response
  if [[ "$response" == "y" ]]; then
    if [[ $command == "apt" ]]; then
        sudo systemctl stop mariadb
        run="sudo $command purge -y mariadb*"
        eval "$run"
    else 
        sudo systemctl stop mariadb
        run="sudo $command remove -y mariadb*"
        eval "$run"
    fi
    sudo rm -rf /var/lib/mysql/*
    sudo rm -f /etc/my.cnf
    sudo rm -f ~/.my.cnf
  else
    echo "Existing MariaDB installation will not be purged. Script aborted."
    exit 5
  fi
fi

install "mariadb-server"

sudo systemctl restart mariadb

echo "--------------------------------------------------------------"
echo "configuring MariaDB"
echo "--------------------------------------------------------------"
sudo mysqladmin --user=root password "$DB_ROOT_USER_PASS"
printf "$DB_ROOT_USER_PASS\n n\n Y\n Y\n Y\n Y\n" | sudo mysql_secure_installation
# sudo mysql -e "SET PASSWORD FOR root@localhost = PASSWORD('$DB_ROOT_USER_PASS');FLUSH PRIVILEGES;"
mysql --user=root --password="$DB_ROOT_USER_PASS" -e "CREATE DATABASE $DB_NAME DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci;"
mysql --user=root --password="$DB_ROOT_USER_PASS" -e "CREATE USER $DB_USER_NAME@localhost IDENTIFIED BY '$DB_USER_PASS';"
mysql --user=root --password="$DB_ROOT_USER_PASS" -e "GRANT ALL ON $DB_NAME.* TO '$DB_USER_NAME'@'localhost' IDENTIFIED BY '$DB_USER_PASS'; FLUSH PRIVILEGES;"

wget -N -P $HOME https://anne.network/files/annedb-latest.sql.zip
sudo unzip -o "$HOME/annedb-latest.sql.zip" -d $HOME
echo "Restoring annedb snap. This should take a while. Please wait..."
mysql -u root -p$DB_ROOT_USER_PASS $DB_NAME < "$HOME/annedb-latest.sql"
rm -f "$HOME/annedb-latest.sql.zip"

curl https://anne.network/files/anne-node.zip --output "$HOME/anne-node.zip"
sudo mkdir "$HOME/annode";
DIR="$HOME/annode";
sudo unzip -o "$HOME/anne-node.zip" -d $DIR
sudo rm -f "$HOME/anne-node.zip"

sudo chown -R $USER:$USER "$HOME/annode"

if [[ $DESKTOP_SESSION == "" ]]; then
    echo "#!/bin/bash
cd $DIR
/usr/bin/java -jar anne-node.jar --headless" > /usr/bin/annode.sh
    sudo chmod +x /usr/bin/annode.sh
    echo "[Unit]
  Description=Annode
  After=network.target
[Service]
  Type=simple
  User=root
  ExecStart=/usr/bin/annode.sh
  Restart=on-abort
[Install]
  WantedBy=multi-user.target" > /etc/systemd/system/annode.service
else
    echo "#!/bin/bash
cd $DIR
/usr/bin/java -jar anne-node.jar" > /usr/bin/annode.sh
    sudo chmod +x /usr/bin/annode.sh
fi

cp "$DIR/conf/node-default.properties" "$DIR/conf/node.properties"

if [[ $DESKTOP_SESSION == "" ]]; then
    sudo systemctl enable annode.service
fi

sed -i "s/DB.Username.*/DB.Username=$DB_USER_NAME/" "$DIR/conf/node.properties"
sed -i "s/DB.Password.*/DB.Password=$DB_USER_PASS/" "$DIR/conf/node.properties"
sed -i "s/anne.nodeAccountId.*/anne.nodeAccountId=$NID/" "$DIR/conf/node.properties"
sed -i "s/anne.nodeSecret.*/anne.nodeSecret=$SECRET/" "$DIR/conf/node.properties"

WANIP=$([ "$(ip link show | grep -c 'tun')" -gt 0 ] && (curl -4 -s ifconfig.me || curl -6 -s ifconfig.me) || (ip -4 route get 1.1.1.1 | grep -oP '(?<=src )[\d.]+' || ip -6 route get 2001:4860:4860::8888 | grep -oP '(?<=src )[\w:]+')); [ "${WANIP//:/}" != "$WANIP" ] && WANIP="[$WANIP]"

sed -i "s/P2P.myAddress.*/P2P.myAddress=$WANIP:$PORT/" "$DIR/conf/node.properties"
sed -i "s/P2P.NumBootstrapConnections.*/P2P.NumBootstrapConnections=25/" "$DIR/conf/node.properties"

sed -i "s/P2P.BootstrapPeers.*/P2P.BootstrapPeers=$PEERSLIST/" "$DIR/conf/node.properties"
sed -i "s/P2P.rebroadcastTo.*/P2P.rebroadcastTo=$PEERSLIST/" "$DIR/conf/node.properties"
 
if [ -n "$LITE" ]; then
  echo "anne.mempool = false" >> "$DIR/conf/node.properties"
fi

if type csf &> /dev/null; then
    # Configure CSF
    current_tcp_in=$(grep 'TCP_IN' /etc/csf/csf.conf | cut -d'=' -f2 | tr -d ' ')
    if [[ ! "$current_tcp_in" =~ "$PORT" ]]; then
        sed -i "s/^TCP_IN = .*/TCP_IN = \"${current_tcp_in},$PORT\"/" /etc/csf/csf.conf
    fi

    current_tcp_out=$(grep 'TCP_OUT' /etc/csf/csf.conf | cut -d'=' -f2 | tr -d ' ')
    if [[ ! "$current_tcp_out" =~ "$PORT" ]]; then
        sed -i "s/^TCP_OUT = .*/TCP_OUT = \"${current_tcp_out},$PORT\"/" /etc/csf/csf.conf
    fi
    csf -r
elif type firewall-cmd &> /dev/null; then
    # Configure firewalld
    firewall-cmd --permanent --add-port=$PORT/tcp
    firewall-cmd --reload
elif type ufw &> /dev/null; then
    # Configure UFW
    ufw allow $PORT/tcp
    ufw reload
fi

echo -e "\e[32m--------------------------------------------------------------\e[0m"
echo -e "\e[32mInstallation Complete\e[0m"
echo -e "\e[32m--------------------------------------------------------------\e[0m"
echo "Welcome to...


                @@@@@@@@@@@@@@@@@@@@@@@@@@@@,
            @@@@@@@@@@@@@@&%%&@@@@@@@@@@@@@@@@@@@@.
         @@@@@@@@@,                        @@@@@@@@@@(
        @@@@@@@@@                                .@@@@@@@@
       @@@@@@@@             %@@@@@@@@                @@@@@@@
     @@@@@@@@            (@@@@@@@@@@@@@.               @@@@@@&
   #@@@@@@@             @@@@@@@@@@@@@@@@.               @@@@@@/
  @@@@@@@@              @@@@@@@@@@@@@@@@/               /@@@@@@
 @@@@@@@@                @@@@@@@@@@@@@@%                 @@@@@@@
@@@@@@@@                    @@@@@@@@@                    @@@@@@@"

echo "Your MariaDB root password is:"
echo "$DB_ROOT_USER_PASS"
echo -e "\e[32m--------------------------------------------------------------\e[0m"
echo "Your 'anneroot' user password for the '$DB_NAME' database is:"
echo "$DB_USER_PASS"
echo -e "\e[32m--------------------------------------------------------------\e[0m"
if [[ $DESKTOP_SESSION == "" ]]; then
    echo "The ANNE node is configured to start automatically in headless mode."
    echo "To start the node now, run:"
    echo "sudo systemctl start annode.service"
    echo -e "\e[32m--------------------------------------------------------------\e[0m"
    echo "To check the node’s status:"
    echo "systemctl status annode.service"
    echo -e "\e[32m--------------------------------------------------------------\e[0m"
    echo "Note: To switch to GUI mode, edit '/usr/bin/annode.sh', remove 
    the '--headless' flag, and restart the service with:"
    echo "sudo systemctl restart annode.service"
else
    echo "To start the ANNE node manually in GUI mode, run:"
    echo "annode.sh"
    echo "Note: To use headless mode, add the '--headless' flag to 
    '/usr/bin/annode.sh' before running."
fi
echo -e "\e[32m--------------------------------------------------------------\e[0m"
echo "View the debug log at:"
echo "$DIR/annode.log"
echo "Use: nano $DIR/annode.log or tail -f $DIR/annode.log"
echo -e "\e[32m--------------------------------------------------------------\e[0m"
echo "To upgrade the ANNE node later, download and run the upgrade script:"
echo "wget https://raw.githubusercontent.com/annemedia/annode-install/main/annode-upgrade.sh"
echo "sudo bash annode-upgrade.sh"
echo -e "\e[32m--------------------------------------------------------------\e[0m"
echo "To upgrade and restore the '$DB_NAME' database from a snapshot, run:"
echo "sudo bash annode-upgrade.sh restore '$DB_ROOT_USER_PASS'"
echo -e "\e[32m--------------------------------------------------------------\e[0m"
echo "IMPORTANT: Save the MariaDB passwords above. They are not stored elsewhere 
and are required for database access."
echo -e "\e[32m--------------------------------------------------------------\e[0m"
