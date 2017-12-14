usage()
{
	echo 'PostgreSQL install script for CentOS 7.x'
	echo ''
    echo 'Usage:'
    echo 'Run it as root. You must specify:'
    echo '    1, Database version: latest|image (latest means the script will try to download the latest 9.6 from pg update site, image means the 9.2 will be installed from the image)'
    echo '    2, Database name'
    echo '    3, Database data root directory, for example /data/postgres - but the parent folder, in this case the /data must exist before run this command!'
    echo '    4, Postgres user password'
    echo '    5, All the other users password'
    echo '    6, the server hostname'
    echo '    7, the server ip address'
    exit 1
}

checkselinux()
{
if [[ $(grep "SELINUX=enforcing" /etc/sysconfig/selinux | wc -l) == 1 ]] ; then
 echo "SELINUX is active! Tablespace creation requires a non-enforcing configuration, please check it! If you have to modify it, the host must be rebooted!"
 false
else
 true
fi
}

# expects two arguments: the hostname and the ip
checkhostfile()
{
if [[ $(grep $2 /etc/hosts | wc -l) == 1 ]] ; then
   echo "Hostfile OK: already contains $2"
else
   echo "Writing hostfile"
   echo "$2 $1" >> /etc/hosts
fi
}

# checks if the specific package is installed or not
function isinstalled
{
  echo "Testing whether $1 is installed or not"
  if yum list installed $1 >/dev/null 2>&1; then
    true
  else
    false
  fi
}

# expects one arg: the database version
installpackages()
{
if isinstalled postgresql96-server ; then
   echo 'PostgreSQL 9.6 is already installed: do nothing'
elif isinstalled postgresql-server ; then
   echo 'PostgreSQL 9.2 is already installed: do nothing'
else
   if [[ $1 == "latest" ]] ; then
     yum -y install https://download.postgresql.org/pub/repos/yum/9.6/redhat/rhel-7-x86_64/pgdg-redhat96-9.6-3.noarch.rpm 
     yum install postgresql96-server -y
   elif [[ $1 == "image" ]] ; then
     echo 'PostgreSQL 9.2 will be installed'
     yum install postgresql-server -y
   else
     echo 'Error: Only latest or image is supported as first argument for this script'
     usage
   fi
fi
}

# checks one port in firewalld 
checkport()
{
echo "Testing whether $1 port is open"
if [[ $(firewall-cmd --list-ports | grep -w $1 | wc -l) == 1 ]] ; then
  echo "Port $1 is already opened"
  true
else
  false
fi
}

# checks whether service is running
isservicerunning()
{
if [[ $(systemctl is-active $1) == 'active'  ]] ; then
  echo "$1 is running"
  true
else
  echo "$1 is not running"
  false
fi
}

# checks a service is enabled or not
# args: service name
function isserviceenabled
{
  echo "Testing whether $1 service is enabled or not"
  if systemctl is-active $1 >/dev/null 2>&1; then
    echo "Service $1 is already enabled"
    true
  else
    false
  fi
}

# open the default port if needed
openport()
{
  if ! ( isserviceenabled firewalld ) ; then
    echo "Enabling firewall"
    systemctl enable firewalld
  else
    echo "Firewall already enabled"
  fi

  if ! ( isservicerunning firewalld ) ; then
    echo "Starting firewall"
    systemctl start firewalld
  else 
    echo "Firewall is running"
  fi

  if ! ( checkport 5432 ) ; then
    echo "Opening default postgres port (5432)"
    firewall-cmd --zone=public --add-port=5432/tcp --permanent
    firewall-cmd --reload
  else
    echo "Port 5432 is already open"
  fi
}

# directory existence check
createdirectory()
{
   if [ -d "$1" ] ; then
      echo "$1 already exists, doing nothing with it"
   else
      echo "Creating $1"
      mkdir $1
      chown -R postgres:postgres $1
   fi
}

# args: version to install: latest|image

initdatabase()
{
    if [[ $1 == "latest" ]] ; then
	if [ ! -f /var/lib/pgsql/9.6/initdb.log ] ; then
	echo "Initing database"
		/usr/pgsql-9.6/bin/postgresql96-setup initdb
	else
		echo "Database already inited"
	fi
    fi
    if [[ $1 == "image" ]] ; then
        if [ ! -f /var/lib/pgsql/initdb.log ] ; then
        echo "Initing database"
                /usr/bin/postgresql-setup initdb
        else
                echo "Database already inited"
        fi
    fi
}

# args: version to install: latest|image

editpostgresqlconf()
{
postgresqlfile=/var/lib/pgsql/data/postgresql.conf
if [[ "latest" == "$1" ]] ; then
   postgresqlfile=/var/lib/pgsql/9.6/data/postgresql.conf
fi
if [[ $( grep "#listen_addresses" $postgresqlfile | wc -l ) == 1 ]] ; then
echo "Editing $postgresqlfile"
sed -i -e"s/^#listen_addresses =.*$/listen_addresses = '*'/" $postgresqlfile
sed -i -e"s/^#max_prepared_transactions =.*$/max_prepared_transactions = 200/" $postgresqlfile
else
echo "Already edited: $postgresqlfile: doing nothing"
fi
}

# args: version to install: latest|image

editpghbaconf()
{
pghbafile=/var/lib/pgsql/data/pg_hba.conf
if [[ "latest" == "$1" ]] ; then
   pghbafile=/var/lib/pgsql/9.6/data/pg_hba.conf
fi
if [[ $( grep "host    all    all    0.0.0.0/0    md5" $pghbafile | wc -l ) == 0 ]] ; then
  echo "Editing $pghbafile"
  echo "host    all    all    0.0.0.0/0    md5" >> $pghbafile
else
  echo "Already edited: $pghbafile: doing nothing"
fi
}

# args: version to install: latest|image

startdatabase()
{
  pgservice=postgresql
  if [[ "latest" == "$1" ]] ; then
    pgservice=postgresql-9.6
  fi
  if ! ( isservicerunning $pgservice ) ; then
    systemctl start $pgservice 
  fi
}

setpostgrespassword()
{
su - postgres -c "psql -e -U postgres -d postgres -c \"alter user postgres with password '$1';\""
}

createdatabaseusingname()
{
if [[ $( su - postgres -c "psql -U postgres -d postgres -l" | grep $1 | wc -l ) == 0 ]] ; then
echo "Database $1 not exists: create..."
su - postgres -c "psql -e -U postgres -d postgres -c \"create database $1 ENCODING 'UTF8' LC_COLLATE 'hu_HU.UTF8' LC_CTYPE='hu_HU.UTF8' template template0;\""
else
echo "Database $1 has been already created"
fi
}

# args: tablespace root folder ($datafolder/$databasename}, tablespace name, databasename

createtablespace()
{
if [[ $( su - postgres -c "echo \"\\db\" | psql $5" | grep $2 | wc -l ) == 0 ]] ; then
echo "Tablespace $2 not exists: create..."
su - postgres -c "psql $5 -e -U postgres -c \"create tablespace $2 location '$1/$2';\""
else
echo "Tablespace $2 has been already created"
fi
}

# args: pguser, pgpassword,tablespace name, hostname, databasename

createuser()
{
if [[ $( su - postgres -c "echo \"\\du\" | psql $5" | grep $1 | wc -l ) == 0 ]] ; then
echo "User $1 not exists: create..."
su - postgres -c "psql $5 -e -U postgres -c \"create user $1 with encrypted password '$2';\""
su - postgres -c "psql $5 -e -U postgres -c \"create schema $1 authorization $1;\""
su - postgres -c "psql $5 -e -U postgres -c \"grant create on tablespace $3 to $1;\""
su - postgres -c "psql $5 -e -U postgres -c \"alter user $1 set default_tablespace to $3;\""
su - postgres -c "export PGPASSWORD=$2;echo \"SET default_tablespace = $3;SET search_path = $1, pg_catalog;\" | psql $5 -e -U $1 -h $4"
else
echo "User $1 has been already created"
fi
}

# args: pgpassword of activiti, hostname, databasename

initactiviti()
{
# by default when the schema is empty in PG the \d will return 'No relations found' in one row
if [[ $( su - postgres -c "export PGPASSWORD=$1;echo \"\\dt\" | psql $3 -U activiti -h $2" | wc -l ) == 1 ]] ; then
echo "Activiti schema is empty, needs to be initialized"
su - postgres -c "export PGPASSWORD=$1;echo \"SET search_path = activiti, pg_catalog;SET default_with_oids = false;\\i $(pwd)/activiti.postgres.create.engine.sql\" | psql $3 -U activiti -h $2"
su - postgres -c "export PGPASSWORD=$1;echo \"SET search_path = activiti, pg_catalog;SET default_with_oids = false;\\i $(pwd)/activiti.postgres.create.history.sql\" | psql $3 -U activiti -h $2"
su - postgres -c "export PGPASSWORD=$1;echo \"SET search_path = activiti, pg_catalog;SET default_with_oids = false;\\i $(pwd)/activiti.postgres.create.identity.sql\" | psql $3 -U activiti -h $2"
else
echo "Activiti schema is already loaded."
fi
}

runinstallation()
{

# write hostfile if needed

checkhostfile $6 $7

# installing packages

installpackages $1

# checking firewall and opening port

openport

# initing database 
initdatabase $1

# creating directories

createdirectory $3
createdirectory $3/$2
createdirectory $3/$2/actspace

# modifying confs

editpostgresqlconf $1
editpghbaconf $1

# start database

startdatabase $1

# set postgres passwd

setpostgrespassword $4

createdatabaseusingname $2

createtablespace $3/$2 actspace $2

createuser activiti $5 actspace $6 $2

# initialize the activiti database, you're gonna need to extract the necessary scripts from activiti engine jar
#initactiviti $5 $6 $2
}

# 
# MAIN
#

if [[ $# != 7 ]] ; then
   usage
else
   if (checkselinux) ; then
   runinstallation "$@"
   fi
fi

