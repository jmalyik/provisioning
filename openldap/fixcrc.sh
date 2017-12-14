if [[ $# != 1 ]] ; then
    echo 'Usage: '
    echo 'You must specify: '
    echo '    2, the ldif file to fix'
    exit 1
fi

grep -v '^#' $1 > /tmp/cleaned.ldif
NEWCRC=$(sed 's/[&/\]/\\&/g' <<< $(crc32 /tmp/cleaned.ldif))
echo "# AUO-GENERATED FILE - DO NOT EDIT!! Use ldapmodify." > $1
echo "# CRC32 $NEWCRC" >> $1
cat /tmp/cleaned.ldif >> $1
rm -f /tmp/cleaned.ldif

