#!/bin/bash
export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

RESTORESNAP="$1"
DB_ROOT_USER_PASS="$2"

if [[ "$RESTORESNAP" = "restore" && -z "$DB_ROOT_USER_PASS" ]]; then
    echo "To restore the database from snap, please provide your MariaDB root password as such..."
    echo "sudo bash annode-upgrade.sh restore yourmariadbrootpassword"
    exit 1
fi

if systemctl list-units --type=service --all | grep annode.service; then
    sudo systemctl stop annode.service
fi

get_package_manager() {
  for manager in apt dnf yum; do
    if which $manager > /dev/null 2>&1; then
      echo $manager
      return
    fi
  done
  echo "This script is running on an unsupported distribution.
      Supported distributions are Debian or RHEL based."
	  exit 1;
}

command=$(get_package_manager)


is_curl_command_available() {
  which curl > /dev/null 2>&1
}

is_wget_command_available() {
  which wget > /dev/null 2>&1
}

if ! is_curl_command_available; then
  run="sudo $command install -y curl"
  eval "$run"
fi

if ! is_wget_command_available; then
  run="sudo $command install -y wget"
  eval "$run"
fi

if [ "$RESTORESNAP" == "restore" ]; then

    MUSER="root"
    MDB="annedb"
    MHOST="localhost"
    MYSQL=$(which mysql)
    AWK=$(which awk)
    GREP=$(which grep)

   rm -f "$HOME/localrelons.sql"
   mysqldump -u root -p$DB_ROOT_USER_PASS $MDB relons_this_annode_only > $HOME/localrelons.sql

    
    # help
    if [ ! $# -ge 1 ]
    then
        echo "Usage: $0 MySQL-anneroot-password"
        echo "Drops all tables from a MySQL"
        exit 2
    fi
    
    # make sure we can connect to server
    $MYSQL -u $MUSER -p$DB_ROOT_USER_PASS -h $MHOST -e "use $MDB"  &>/dev/null
    if [ $? -ne 0 ]
    then
        echo "Error - Cannot connect to mysql server using given username, password or database does not exits!"
        exit 3
    fi
    
    TABLES=$($MYSQL -u $MUSER -p$DB_ROOT_USER_PASS -h $MHOST $MDB -e 'show tables' | $AWK '{ print $1}' | $GREP -v '^Tables' )
    
    # make sure tables exits
    if [ "$TABLES" == "" ]
    then
        echo "Error - No table found in $MDB database!"
        #exit 4
    fi
    
    # let us do it
    for t in $TABLES
    do
        echo "Deleting $t table from $MDB database..."
        $MYSQL -u $MUSER -p$DB_ROOT_USER_PASS -h $MHOST $MDB -e "SET FOREIGN_KEY_CHECKS = 0; drop table $t; SET FOREIGN_KEY_CHECKS = 1"	
    done

    TABLES=$($MYSQL -u $MUSER -p$DB_ROOT_USER_PASS -h $MHOST $MDB -e 'show tables' | $AWK '{ print $1}' | $GREP -v '^Tables' )

    for t in $TABLES
    do
        echo "Deleting $t view from $MDB database..."
        $MYSQL -u $MUSER -p$DB_ROOT_USER_PASS -h $MHOST $MDB -e "drop view $t;"
        
    done
   
   wget -N -P $HOME https://anne.network/files/annedb-latest.sql.zip
   unzip -o "$HOME/annedb-latest.sql.zip" -d $HOME

   echo "Restoring annedb snap. Please wait..."
   mysql -u $MUSER -p$DB_ROOT_USER_PASS $MDB < "$HOME/annedb-latest.sql"
   echo "Restoring local relons table. Please wait..."
   mysql -u $MUSER -p$DB_ROOT_USER_PASS -D $MDB < "$HOME/localrelons.sql"
   rm -f "$HOME/localrelons.sql"
   rm -f "$HOME/annedb-latest.sql.zip"
fi

echo "Getting new annode version. Please wait..."
curl https://anne.network/files/anne-node.zip --output "$HOME/anne-node.zip"
DIR="$HOME/annode";
sudo unzip -o "$HOME/anne-node.zip" -d $DIR
sudo rm -f "$HOME/anne-node.zip"


if systemctl list-units --type=service --all | grep annode.service; then
   sudo systemctl start annode.service
fi

echo "----------------------------------------------------"
echo "If new version was available at" 
echo "https://anne.network/files/anne-node.zip"
echo "then your annode has been upgraded."
echo "----------------------------------------------------"
