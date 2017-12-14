usage()
{
	echo 'Jboss 7.0 EAP install script for CentOS 7.x - for alfresco 5.2g'
	echo ''
    echo 'Run it as root. You must specify:'
    echo '    1, Install material folder'
    echo '    2, jboss target folder, e.q.: /usr/share/jboss-as'
    echo '    3, jboss service name'
    echo '    4, jboss user name'
    echo '    5, the server hostname'
    echo '    6, the server ip address'
    echo '    7, debug port, jboss will be started in debug mode, specify 0 if jboss should be started in normal mode'
    exit 1
}

# checks one port in firewalld 
# args: port
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
# args: service name
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

  if ! ( checkport 8080 ) ; then
    echo "Opening default jboss port (8080)"
    firewall-cmd --zone=public --add-port=8080/tcp --permanent
    firewall-cmd --reload
  else
    echo "Port 5432 is already open"
  fi
} 

# adds the given hostname and ip to the hostfile if needed
# args: the hostname and the ip
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
# args: package name
function isinstalled
{
  echo "Testing whether $1 is installed or not"
  if yum list installed $1 >/dev/null 2>&1; then
    true
  else
    false
  fi
}

# installs all required packages
function install_packages
{
   if ! ( isinstalled unzip ) ; then
        echo "installing unzip"
        yum -y install unzip
   else
        echo "unzip already installed"
   fi
} 

# args: install material folder
jbosszipexists()
{
   if [ -f $1/jboss-eap-7.0.0.zip ] ; then
      echo "$1/jboss-eap-7.0.0.zip is exists in install material directory"
   else
      echo "File $1/jboss-eap-7.0.0.zip does not exists: installation failed"
      exit 1
   fi 
} 

# args: user name
isuserexists()
{
    if id "$1" >/dev/null 2>&1 ; then
        echo "$1 user exists"
        true
    else
        echo "$1 user does not exist"
        false
    fi
}

# args: group name
isgroupexists()
{
   if [ $(grep -c "$1" /etc/group) == 1 ] ; then
        echo "$1 group exists"
        true
    else
        echo "$1 group does not exist"
        false
    fi
}

# args: jboss user (and the default group) name
createjbossuserandgroup()
{
    if isgroupexists $1 ; then
	echo "$1 group already created"
    else
	echo "creating $1 group"
	groupadd -r $1 -g 1000
    fi
    if isuserexists $1 ; then
        echo "$1 user already created"
    else
        echo "creating $1 user"
        useradd -u 1000 -r -g $1 -m -d /home/$1 -s /sbin/nologin -c "$1 user" $1
	chown -R $1:$1 /home/$1
    fi
}

# args: directory path, owner
createdirectory()
{
   if [ -d "$1" ] ; then
      echo "$1 already exists, doing nothing with it"
   else
      echo "Creating $1"
      mkdir -p $1
      chown -R $2:$2 $1
   fi
} 

#args: installmaterial folder, jboss target folder, jboss service name, jboss user
unzipjboss()
{
echo "$@"
    if [ -d $2 ] ; then
    	echo "$2 already exists: it seems jboss is already installed: do nothing"
    else
        echo "$2 does not exist: unzipping $1/jboss-eap-7.0.0.zip to /usr/share"
	unzip -q $1/jboss-eap-7.0.0.zip -d /usr/share
	cd /usr/share
	echo "moving /usr/share/jboss-eap-7.0 to $2"
	mv /usr/share/jboss-eap-7.0 $2
	chown -R $4:$4 $2
    fi
}

#args: jboss target folder, jboss service name, jboss user
create_jboss_as_conf()
{
if [ -f /etc/jboss-as/$2.conf ] ; then
	echo "File /etc/jboss-as/$2.conf already exists"
else
	echo "writing /etc/jboss-as/$2.conf"
	cat > /etc/jboss-as/$2.conf <<EOF
JBOSS_USER=$3
STARTUP_WAIT=300
SHUTDOWN_WAIT=30
JBOSS_CONSOLE_LOG=/var/log/$2/server.log
JBOSS_HOME=$1
JAVA_HOME=/usr/java/default
EOF
fi
}

#args: jboss target folder, jboss service name, jboss user, debugport
create_jboss_service()
{
if [ -f /etc/systemd/system/$2.service ] ; then
        echo "File /etc/systemd/system/$2.service already exists"
else
	echo "writing /etc/systemd/system/$2.service"

debugstr="--debug $4"
if [[ "$2" == "0" ]] ; then
	debugstr=""
fi

cat > /etc/systemd/system/$2.service <<EOF
Description=Jboss Application Server ($2 instance)
After=syslog.target network.target

[Service]
Type=idle
Environment=JAVA_HOME=/usr/java/default JBOSS_HOME=$1 JAVA=/usr/java/default/bin/java JBOSS_LOG_DIR=/var/log/$2
User=$3
Group=$3
ExecStart=$1/bin/standalone.sh $debugstr
EOF
fi
} 

# args: jboss target folder
set_java_opts()
{
if [[ $(grep "file.encoding" $1/bin/standalone.conf | wc -l) == 1 ]] ; then
	echo "$1/bin/standalone.conf already modified"
else
	echo "modifying $1/bin/standalone.conf file"
cp $1/bin/standalone.conf $1/bin/standalone.conf.backup
sed -i '/MetaspaceSize/c\JAVA_OPTS="$JAVA_OPTS -Xms4096m -Xmx4096m -XX:MetaspaceSize=256M -XX:MaxMetaspaceSize=768m -Djava.net.preferIPv4Stack=true -Dfile.encoding=UTF-8"' $1/bin/standalone.conf
fi
}

# args: jboss target folder
change_bind_address()
{
echo "modifying bind address to enable external address on http port"
sed -i "s@\${jboss.bind.address:127.0.0.1}@\${jboss.bind.address:0.0.0.0}@" $1/standalone/configuration/standalone.xml
}

# args: jboss target folder
disable_webservices_subsystem_in_jboss()
{
if [[ $(grep "org.jboss.as.webservices" $1/standalone/configuration/standalone.xml | wc -l) == 0 ]] ; then
	echo "org.jboss.as.webservices already removed from $1/standalone/configuration/standalone.xml"
else
	echo "Removing org.jboss.as.webservices from $1/standalone/configuration/standalone.xml"
	sed -i '/org.jboss.as.webservices/c\' $1/standalone/configuration/standalone.xml
	cp $1/standalone/configuration/standalone.xml /tmp
	awk '/<subsystem xmlns=\"urn\:jboss\:domain\:webservices\:2.0\">+$/, /<\/subsystem>+$/{next}1' /tmp/standalone.xml > $1/standalone/configuration/standalone.xml
	rm -f /tmp/standalone.xml
fi
}

# args: jboss target folder
disable_jsf_subsystem_in_jboss()
{
if [[ $(grep "urn\:jboss\:domain\:jsf\:1.0" $1/standalone/configuration/standalone.xml | wc -l) == 0 ]] ; then
	echo "urn:jboss:domain:jsf:1.0 already removed from $1/standalone/configuration/standalone.xml"
else
	echo "Removing urn:jboss:domain:jsf:1.0 from $1/standalone/configuration/standalone.xml"
        sed -i '/org.jboss.as.jsf/c\' $1/standalone/configuration/standalone.xml
	sed -i '/urn:jboss:domain:jsf:1.0/c\' $1/standalone/configuration/standalone.xml
fi
}

# args: jboss target folder
open_ajp_port()
{
if [[ $(grep "<ajp-listener name=\"ajp\" socket-binding=\"ajp\" scheme=\"http\"/>" $1/standalone/configuration/standalone.xml | wc -l) == 1 ]] ; then
	echo "ajp listener already added"
else
	echo "adding ajp listener"
	sed -i '/<server name="default-server">/c\<server name="default-server"><ajp-listener name="ajp" socket-binding="ajp" scheme="http"/>' $1/standalone/configuration/standalone.xml
fi
}

# args: install material folder, jboss target folder, jboss user
add_postgresql_driver()
{
if [[ $(grep "<driver name=\"postgresql\" module=\"org.postgresql.driver\"/>" $2/standalone/configuration/standalone.xml | wc -l) == 1 ]] ; then
	echo "postgres driver already added to jboss"
else
	echo "adding postgres driver to jboss"
	sed -i '/<\/drivers>/c\\t\t\t<driver name="postgresql" module="org.postgresql.driver"/>\n\t\t</drivers>' $2/standalone/configuration/standalone.xml
fi
if [ -f $1/postgresql-42.0.0.jar ] ; then
	if [ ! -f $2/modules/org/postgresql/driver/main/postgresql-42.0.0.jar ] ; then
		echo "copying postgres driver $1/postgresql-42.0.0.jar to $2/modules/org/postgresql/driver/main/postgresql-42.0.0.jar"
		cp $1/postgresql-42.0.0.jar $2/modules/org/postgresql/driver/main/postgresql-42.0.0.jar
		create_driver_xml $2 $3
		chown $3:$3 $2/modules/org/postgresql/driver/main/postgresql-42.0.0.jar
	else
		echo "Postres driver is already installed"	
	fi
else
	echo "Postgres driver $1/postgresql-42.0.0.jar does not exists: installation failed"
fi
}

# jboss target folder, jboss user
create_driver_xml()
{
cat > $1/modules/org/postgresql/driver/main/module.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>  
<module xmlns="urn:jboss:module:1.0" name="org.postgresql.driver">  
 <resources>  
 <resource-root path="postgresql-42.0.0.jar"/>  
 </resources>  
 <dependencies>  
 <module name="javax.api"/>  
 <module name="javax.transaction.api"/>
 </dependencies>
</module>
EOF
chown $2:$2 $1/modules/org/postgresql/driver/main/module.xml
}


runinstallation()
{
install_packages
openport
checkhostfile $6 $5
jbosszipexists $1
createjbossuserandgroup $4
createdirectory /etc/$3 $4
unzipjboss $1 $2 $3 $4
create_jboss_as_conf $2 $3 $4
createdirectory /var/log/$3 $4
createdirectory /var/run/$3 $4
create_jboss_service $2 $3 $4 $7
set_java_opts $2
change_bind_address $2
disable_webservices_subsystem_in_jboss $2
disable_jsf_subsystem_in_jboss $2
open_ajp_port $2
createdirectory $2/modules/org $4
createdirectory $2/modules/org/postgresql $4
createdirectory $2/modules/org/postgresql/driver $4
createdirectory $2/modules/org/postgresql/driver/main $4
add_postgresql_driver $1 $2 $4
}

# 
# MAIN
#

if [[ $# != 7 ]] ; then
   usage
else
   runinstallation "$@"
fi 
