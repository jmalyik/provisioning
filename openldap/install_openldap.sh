usage()
{
	echo 'OpenLDAP install script for CentOS 7.x'
	echo ''
    echo 'Run it as root. You must specify:'
    echo 'Usage: '
    echo 'You must specify: '
    echo '    1, the ldap password of ldap administrator and bind user!'
    echo '    2, the base dn'
    echo '    3, the ldap server hostname'
    echo '    4, the ldap server ip address'
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
if isinstalled openldap-servers ; then
   echo 'OpenLDAP is already installed: do nothing'
else
   echo 'Installing OpenLDAP'
   yum -y install openldap compat-openldap openldap-clients openldap-servers openldap-servers-sql openldap-devel perl-Archive-Zip
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

  if ! ( checkport 389 ) ; then
    echo "Opening default postgres port (389)"
    firewall-cmd --zone=public --add-port=389/tcp --permanent
    firewall-cmd --reload
  else
    echo "Port 389 is already open"
  fi
}

# args: root/bind password, basedn
createschema()
{
	echo "modifying schema before the first start"

	cp /etc/openldap/slapd.d/cn\=config/cn\=schema/cn={0}core.ldif /etc/openldap/slapd.d/cn\=config/cn\=schema/cn={0}core.ldif.backup
	cp cn={0}core.ldif /etc/openldap/slapd.d/cn\=config/cn\=schema

	# we have to correct the CRC in the file

	./fixcrc.sh /etc/openldap/slapd.d/cn=config/cn=schema/cn={0}core.ldif

	cp /etc/openldap/slapd.d/cn\=config.ldif /etc/openldap/slapd.d/cn\=config.ldif.backup
	echo "olcSizeLimit: -1" >> /etc/openldap/slapd.d/cn\=config.ldif

	# we have to correct the CRC in the file

	./fixcrc.sh /etc/openldap/slapd.d/cn\=config.ldif

	cp /etc/openldap/slapd.d/cn\=config/olcDatabase={2}hdb.ldif /etc/openldap/slapd.d/cn\=config/olcDatabase={2}hdb.ldif.backup
	sed -i -e 's/dc=my-domain,dc=com/'"$2"'/g' /etc/openldap/slapd.d/cn\=config/olcDatabase={2}hdb.ldif

	ENCPASSWD=$(sed 's/[&/\]/\\&/g' <<< $(slappasswd -s $1 -n))

	echo "olcRootPW: $ENCPASSWD" >> /etc/openldap/slapd.d/cn\=config/olcDatabase={2}hdb.ldif

	# we have to correct the CRC in the file

	./fixcrc.sh /etc/openldap/slapd.d/cn\=config/olcDatabase={2}hdb.ldif

	cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
	chown ldap:ldap /var/lib/ldap/DB_CONFIG
}

enableandstart()
{
  if ! ( isserviceenabled slapd ) ; then
    echo "Enabling firewall"
    systemctl enable slapd
  else
    echo "Slapd already enabled"
  fi

  if ! ( isservicerunning slapd ) ; then
    echo "Starting slapd"
    systemctl start slapd
  else 
    echo "Slapd is running"
  fi

}

addbuiltinschemas()
{
echo "adding built-in used schemas"

ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif
}

#args: ldap admin password, basedn

addbasestructure()
{
echo "adding base structure"
cp baseStructureTemplate.ldif /tmp
sed -i -e 's/$BASEDN/'"$2"'/g' /tmp/baseStructureTemplate.ldif
sed -i -e 's/$ENCPASSWD/'"$ENCPASSWD"'/g' /tmp/baseStructureTemplate.ldif
ldapadd -H ldap://localhost -x -D "cn=Manager,$2"  -f /tmp/baseStructureTemplate.ldif -w $1
}


runinstallation()
{

# write hostfile if needed

checkhostfile $3 $4

# installing packages

installpackages

# checking firewall and opening port

openport

createschema $1 $2

enableandstart

addbuiltinschemas

addbasestructure $1 $2
}

# 
# MAIN
#

if [[ $# != 4 ]] ; then
    usage
    exit 1
else
   if [ -x fixcrc.sh ] ; then
      runinstallation "$@"
   else
      echo "fixcrc.sh not found or not executeable!"
   fi
fi
