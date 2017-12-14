usage()
{
    echo 'Usage:'
    echo 'You must specify:'
    echo '    1, Install material folder'
    echo '    2, jboss target folder, e.q.: /usr/share/jboss-as'
    echo '    3, jboss user name'
    exit 1
}

checkfiles()
{
if [ ! -f $1/share-5.2.f.war ] ; then
	echo "Missing $1/share-5.2.f.war: installation failed!"
	exit 1
fi
if [ ! -f $1/alfresco-mmt-5.2.g.jar ] ; then
    echo "Missing $1/alfresco-mmt-5.2.g.jar: installation failed!"
    exit 1
fi

echo "share.war and share amp and alfresco-mmt.jar are present"
}

create_jboss_deployment_descriptor()
{
if [ -f /tmp/share/WEB-INF/jboss-deployment-structure.xml ] ; then
	echo "/tmp/share/WEB-INF/jboss-deployment-structure.xml already exists: doing nothing"
else
	echo "Creating jboss-deployment-descriptor.xml"
cat > /tmp/share/WEB-INF/jboss-deployment-structure.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<jboss-deployment-structure>
 <deployment>
  <dependencies>
   <module name="org.alfresco.configuration" />
  </dependencies>
 </deployment>
</jboss-deployment-structure>
EOF
fi
}

add_logging_profile()
{
if [[ $(grep "Logging-Profile" /tmp/share/META-INF/MANIFEST.MF | wc -l) == 0 ]] ; then
echo "addig logging profile"
cp /tmp/share/META-INF/MANIFEST.MF /tmp/MANIFEST_ORIG.MF
sed -i -e 's/\r$//g' /tmp/share/META-INF/MANIFEST.MF
perl -i -p0e 's/shar\s+?e/share/s' /tmp/share/META-INF/MANIFEST.MF
all=$(cat /tmp/share/META-INF/MANIFEST.MF | wc -l)
head -n 18 /tmp/share/META-INF/MANIFEST.MF > /tmp/MANIFEST.MF
echo -e "Logging-Profile: share" >> /tmp/MANIFEST.MF
rest=$((all - 20))
tail -n $rest /tmp/share/META-INF/MANIFEST.MF >> /tmp/MANIFEST.MF
cp /tmp/MANIFEST.MF /tmp/share/META-INF/MANIFEST.MF -f
cp /tmp/share/META-INF/MANIFEST.MF /tmp/MANIFEST_MODDED.MF
else
echo "logging profile already added"
fi
}

unzipsharewar()
{
if [ -d /tmp/share ] ; then
	echo "/tmp/share already exists: doing nothing"
else
	echo "Unzipping share.war"
	mkdir /tmp/share
	cp $1/share-5.2.f.war /tmp/share
	cd /tmp/share
        unzip -q share-5.2.f.war
	rm -f share-5.2.f.war
fi
}

zipsharewar()
{
if [ -f /tmp/share.war ] ; then
	echo "/tmp/share.war already created: doing nothing"
else
	echo "creating share.war in /tmp"
	cd /tmp/share
	zip -q -r /tmp/share.war *
fi
}

runinstallation()
{
	checkfiles $1
	unzipsharewar $1
	create_jboss_deployment_descriptor
	add_logging_profile
	zipsharewar
	cp -f /tmp/share.war $2/standalone/deployments
	chown $3:$3 $2/standalone/deployments/share.war
}

#
# MAIN
#

if [[ $# != 3 ]]; then
   usage
else
   runinstallation "$@"
fi

