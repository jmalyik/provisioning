usage()
{
    echo 'Usage:'
    echo 'You must specify:'
    echo '    1, Install material folder'
    echo '    2, jboss target folder, e.q.: /usr/share/jboss-as'
    echo '    3, jboss user name'
    echo '    4, alfresco data folder e.g.: /data/alfresco'
    echo '    5, alfresco admin password'
    echo '    6  alfresco data source e.g.: AlfrescoDS'
    echo '    7, database name'
    echo '    8, database hostname'
    echo '    9, database port'
    echo '   10, database user'
    echo "   11, database user's password"
    echo '   12, ldap host'
    echo '   13, ldap bind user (with double escaped (!) DN, e.g.: uid\\=ldapbind,ou\\=Technical,dc\\=myproject,dc\\=local)'
    echo "   14, ldap bind user's password"
    echo '   15, ldap group search base (with double escaped DN, e.g.: ou\\=Groups,ou\\=Normal,dc\\=myproject,dc\\=local)'
    echo '   16, ldap user search base (with double escaped DN, e.g.: ou\\=Users,ou\\=Normal,dc\\=myproject,dc\\=local)'
    exit 1
}

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
   if ! ( isinstalled zip ) ; then
        echo "installing zip"
        yum -y install zip
   else
        echo "zip already installed"
   fi
}  

# args: directory path, owner
createdirectory()
{
   if [ -d "$1" ] ; then
      echo "$1 already exists, doing nothing with it"
   else
      echo "Creating $1"
      mkdir $1
      chown -R $2:$2 $1
   fi
} 

# args: target jboss folder, jboss user
create_alf_jboss_module_conf()
{
if [ -f $1/modules/org/alfresco/configuration/main/module.xml ] ; then
echo "$1/modules/org/alfresco/configuration/main/module.xml already exists"
else
echo "writing $1/modules/org/alfresco/configuration/main/module.xml"
cat > $1/modules/org/alfresco/configuration/main/module.xml <<EOF 
<?xml version="1.0" encoding="UTF-8"?>
  <module xmlns="urn:jboss:module:1.0" name="org.alfresco.configuration">
    <resources>
     <resource-root path="."/>
    </resources>
  </module>
EOF
chown $2:$2 $1/modules/org/alfresco/configuration/main/module.xml
fi
}

create_alf_global_properties()
{
if [ -f $2/modules/org/alfresco/configuration/main/alfresco-global.properties ] ; then
echo "$2/modules/org/alfresco/configuration/main/alfresco-global.properties already exists"
else
echo "writing $2/modules/org/alfresco/configuration/main/alfresco-global.properties"

cat > $2/modules/org/alfresco/configuration/main/alfresco-global.properties <<EOF
dir.root=$4/alfresco
ooo.enabled=false
jodconverter.enabled=false
alfresco_user_store.adminpassword=$5
alfresco.authentication.allowGuestLogin=true
authentication.chain=alfrescoNtlm1:alfrescoNtlm,ldap1:ldap,external1:external
external.authentication.enabled=true
external.authentication.proxyUserName=
synchronization.synchronizeChangesOnly=false
synchronization.import.cron=0 */30 * * * ?
cifs.enabled=falsehibernate.dialect=org.hibernate.dialect.PostgreSQLDialect
db.driver=org.postgresql.Driver
db.url=jdbc:postgresql://\${db.host}:\${db.port}/\${db.name}
db.name=$7
db.username=${10}
db.password=${11}
db.host=$8
db.port=$9
db.pool.max=100
system.workflow.engine.jbpm.enabled=false
system.workflow.engine.jbpm.definitions.visible=false
system.workflow.engine.activiti.enabled=false
system.workflow.engine.activiti.definitions.visible=false
EOF
fi
}

create_alf_ldap_conf()
{
confdir=$2/modules/org/alfresco/configuration/main/alfresco/extension/subsystems/Authentication/ldap/ldap1
createdirectory $2/modules/org $3
createdirectory $2/modules/org/alfresco $3
createdirectory $2/modules/org/alfresco/configuration $3
createdirectory $2/modules/org/alfresco/configuration/main $3
createdirectory $2/modules/org/alfresco/configuration/main/alfresco $3
createdirectory $2/modules/org/alfresco/configuration/main/alfresco/extension $3
createdirectory $2/modules/org/alfresco/configuration/main/alfresco/extension/subsystems $3
createdirectory $2/modules/org/alfresco/configuration/main/alfresco/extension/subsystems/Authentication $3
createdirectory $2/modules/org/alfresco/configuration/main/alfresco/extension/subsystems/Authentication/ldap $3
createdirectory $confdir $3
if [ -f $confdir/ldap-authentication.properties ] ; then
echo "$confdir/ldap-authentication.properties  already exists"
else
echo "writing $confdir/ldap-authentication.properties"
cat > $confdir/ldap-authentication.properties <<EOF
ldap.authentication.active=true
ldap.authentication.allowGuestLogin=true
ldap.authentication.java.naming.factory.initial=com.sun.jndi.ldap.LdapCtxFactory
ldap.authentication.java.naming.provider.url=ldap://${12}:389
ldap.authentication.java.naming.security.authentication=simple
ldap.authentication.escapeCommasInBind=false
ldap.authentication.escapeCommasInUid=false
ldap.authentication.defaultAdministratorUserNames=
ldap.synchronization.active=true
ldap.synchronization.java.naming.security.authentication=simple
ldap.synchronization.java.naming.security.principal=${13}
ldap.synchronization.java.naming.security.credentials=${14}
ldap.synchronization.queryBatchSize=0
ldap.synchronization.attributeBatchSize=0
ldap.synchronization.groupQuery=(objectclass\=groupOfUniqueNames)
ldap.synchronization.groupDifferentialQuery=(&(objectclass\=groupOfUniqueNames)(!(modifyTimestamp<\={0})))
ldap.synchronization.personQuery=(objectclass\=inetOrgPerson)
ldap.synchronization.personDifferentialQuery=(&(objectclass\=inetOrgPerson)(!(modifyTimestamp<\={0})))
ldap.synchronization.groupSearchBase=${15}
ldap.synchronization.userSearchBase=${16}
ldap.synchronization.modifyTimestampAttributeName=modifyTimestamp
ldap.synchronization.timestampFormat=yyyyMMddHHmmss'Z'
ldap.synchronization.userIdAttributeName=uid
ldap.synchronization.userFirstNameAttributeName=givenName
ldap.synchronization.userLastNameAttributeName=sn
ldap.synchronization.userEmailAttributeName=mail
ldap.synchronization.userOrganizationalIdAttributeName=o
ldap.synchronization.defaultHomeFolderProvider=largeHomeFolderProvider
ldap.synchronization.groupIdAttributeName=cn
ldap.synchronization.groupDisplayNameAttributeName=description
ldap.synchronization.groupType=groupOfUniqueNames
ldap.synchronization.personType=inetOrgPerson
ldap.synchronization.groupMemberAttributeName=uniqueMember
ldap.synchronization.enableProgressEstimation=true
ldap.authentication.java.naming.read.timeout=0
EOF

fi
}

add_alf_logging_profile()
{
if [[ $(grep "ALFFILE" $1 | wc -l) == 0 ]] ; then
	echo "adding alfresco logging profile"
	fulllength=$(cat $1 | wc -l)
	position=$(awk '/<subsystem xmlns="urn:jboss:domain:logging:3.0">/{print NR;exit}' $1)
	head -n $position $1 > /tmp/standalone.xml
	cat alfresco_war_logging.xml >> /tmp/standalone.xml
	lastpart=$(($fulllength - $position))
	tail -n $lastpart $1 >> /tmp/standalone.xml
	cp $1 $1.before.alf.logging
	mv /tmp/standalone.xml $1
else
	echo "alfresco logging profile already added"
fi
}

configure_alfresco_war()
{
	echo "configuring alfresco.war..."
	if [ ! -f $1/alfresco-platform-5.2.g.war ] ; then
		echo "Missing $1/alfresco-platform-5.2.g.war: installation failed!"
		exit 1
	else
		if [ ! -f /tmp/alfresco.war ] ; then
			echo "Missing manipulated /tmp/alfresco.war war file, creating..."
			mkdir /tmp/alf
			cp $1/alfresco-platform-5.2.g.war /tmp/alf
			cd /tmp/alf
			echo "unzipping alfresco.war..."
			unzip -q alfresco-platform-5.2.g.war
			rm -f alfresco-platform-5.2.g.war
			echo "replacing datasource references"
			sed -i -e 's/datasources\/MySqlDS/'"$2"'/g' /tmp/alf/WEB-INF/jboss-web.xml
			echo "placing jboss-deployment-structure.xml"
			create_jboss_deployment_structure /tmp/alf/WEB-INF
			fix_manifest_error /tmp/alf/META-INF
			add_logging_profile_to_manifest /tmp/alf/META-INF
			echo "zipping /tmp/alfesco.war..."
			zip -q -r /tmp/alfresco.war *
			cd ~
			rm -Rf /tmp/alf
		else
			echo "Found manipulated /tmp/alfresco.war, do nothing"
		fi
	fi
}

fix_manifest_error()
{
sed -i -e 's/\r$//g' $1/MANIFEST.MF
perl -i -p0e 's/a\s+?lfresco/alfresco/s' $1/MANIFEST.MF
}

add_logging_profile_to_manifest()
{
echo "adding logging profile"
cp $1/MANIFEST.MF /tmp/MANIFEST_ORIG.MF
all=$(cat $1/MANIFEST.MF | wc -l)
head -n 18 $1/MANIFEST.MF > /tmp/MANIFEST.MF
echo -e "Logging-Profile: alfresco" >> /tmp/MANIFEST.MF
rest=$((all - 18))
tail -n $rest $1/MANIFEST.MF /tmp/MANIFEST.MF
cp /tmp/MANIFEST.MF $1/MANIFEST.MF -f

cp $1/MANIFEST.MF /tmp/MANIFEST_MODDED.MF
}

create_jboss_deployment_structure()
{
cat > $1/jboss-deployment-structure.xml  <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<jboss-deployment-structure>
 <deployment>
  <exclude-subsystems>
   <subsystem name="webservices" />
  </exclude-subsystems>
  <dependencies>
   <module name="org.alfresco.configuration" />
   <module name="org.apache.xalan" />
  </dependencies>
 </deployment>
</jboss-deployment-structure>
EOF
}

apply_repo_amp_and_share_services_amp()
{
	if [ ! -f $1/alfresco-mmt-5.2.g.jar ] ; then
		echo "Missing $1/alfresco-mmt-5.2.g.jar : installation failed"
		exit 1
	fi
 
	if [ ! -f $1/alfresco-share-services-5.2.f.amp ] ; then
		echo "Missing $1/alfresco-share-services-5.2.f.amp : installation failed"
		exit 1
	fi

	cd $1
	echo "Applying share-services amp"
	java -jar alfresco-mmt-5.2.g.jar install alfresco-share-services-5.2.f.amp /tmp/alfresco.war
}

deploy_alfresco_war()
{
if [ -f $1/standalone/deployments/alfresco.war ] ; then
	echo "$1/standalone/deployments/alfresco.war already exists: do nothing"
else
	echo "Copying /tmp/alfresco.war to $1/standalone/deployments"
	cp /tmp/alfresco.war $1/standalone/deployments
	chown $2:$2 $1/standalone/deployments/alfresco.war
fi
}

runinstallation()
{
  install_packages
  createdirectory $4 $3
  createdirectory $2/modules/org $3
  createdirectory $2/modules/org/alfresco $3
  createdirectory $2/modules/org/alfresco/configuration $3
  createdirectory $2/modules/org/alfresco/configuration/main $3
  create_alf_jboss_module_conf $2 $3
  create_alf_global_properties "$@"
  create_alf_ldap_conf "$@"
  add_alf_logging_profile $2/standalone/configuration/standalone.xml
  configure_alfresco_war $1 $6
  apply_repo_amp_and_share_services_amp $1
  deploy_alfresco_war $2 $3
}

# 
# MAIN
#

if [[ $# != 16 ]]; then
   usage
else
   runinstallation "$@"
fi 
