usage()
{
    echo 'Usage:'
    echo 'You must specify:'
    echo '    1, standalone.xml full path e.g.: /usr/share/jboss-as/standalone/configuration/standalone.xml'
    echo '    2, datasource template xml, e.g.: datasource_template.xml'
    echo '    3, datasource name, e.g.: AlfrescoDS'
    echo '    4, database host'
    echo '    5, database port, in case of PostgreSQL, the default is 5432'
    echo '    6, database name'
    echo '    7, database user'
    echo '    8, database password'
    exit 1
}

# args:
# - target file
# - descriptor template
# - datasource name
# - db host
# - db port
# - db name
# - db user
# - db port
replace_datasource_descriptor()
{
	cp $2 /tmp/$1
	sed -i -e 's/$DATASOURCENAME/'"$3"'/g' /tmp/$1
	sed -i -e 's/$DBHOST/'"$4"'/g' /tmp/$1
	sed -i -e 's/$DBPORT/'"$5"'/g' /tmp/$1
        sed -i -e 's/$DBNAME/'"$6"'/g' /tmp/$1
        sed -i -e 's/$DBUSER/'"$7"'/g' /tmp/$1
        sed -i -e 's/$DBPASSWORD/'"$8"'/g' /tmp/$1
}

runinstallation()
{
if [[ $(grep $3 $1 | wc -l) == 0 ]] ; then
	echo "Appending $3 datasource to $1"
	replace_datasource_descriptor datasource.xml "${@:2}"
	fulllength=$(cat $1 | wc -l)
	position=$(awk '/<\/datasource>/{print NR;exit}' $1)
	head -n $position $1 > /tmp/standalone.xml
	cat /tmp/datasource.xml >> /tmp/standalone.xml
	lastpart=$(($fulllength - $position))
	tail -n $lastpart $1 >> /tmp/standalone.xml
	cp $1 $1.before.$3
	mv /tmp/standalone.xml $1
else
	echo "DataSource $3 has already been added to $1"
fi
}

# 
# MAIN
#

if [[ $# != 8 ]] ; then
   usage
else
   runinstallation "$@"
fi  
