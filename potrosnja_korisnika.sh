#!/bin/sh
# (C) Dinko Korunic, InfoMAR, 2011

LANG=C
PATH=/usr/kerberos/sbin:/usr/kerberos/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin

SPACE1="  "
SPACE2="${SPACE1}${SPACE1}"
IONICE="ionice -c3 -n7"

echo "total: $(df -k / | tail -n 1 | awk '{print $3}')"
echo "users:"

while read LINE; do
	# ako linija zapocinje sa komentarom
	echo $LINE | grep -q '^#' && continue

	# doznaj sve bitne podatke za pojedini redak
	user=$(echo $LINE | awk '{print $1}')
	domains=$(echo $LINE | awk '{ for (i = 1; i <= NF; i++) { if ($i ~ /^d:/) {  sub(/^d:/, "", $i); print $i } } }')
	paths=$(echo $LINE | awk '{ for (i = 1; i <= NF; i++) { if ($i ~ /^p:/) {  sub(/^p:/, "", $i); print $i } } }'; echo $LINE | awk '{ for (i = 1; i <= NF; i++) { if ($i ~ /^d:/) {  sub(/^d:/, "", $i); print "/var/spool/mail/" $i } } }')

	# headeri
	echo "-"
	echo "${SPACE1}uid: $user"
	
	# ispis potrosnje diska
	data=0
	for i in $paths; do
		if [ -d $i ]; then
			tmpdata=$($IONICE du -ks $i | awk '{print $1}')
			[ ! -z $tmpdata ] && data=$(expr $data + $tmpdata)
		fi
	done
	echo "${SPACE1}data: $data"

	# ispis domena
	echo "${SPACE1}domains:"
	for i in $domains; do
		echo "${SPACE2}- $i"
	done

	# ispis emailova
	echo "${SPACE1}emails:"

	# ispis potrosnje pojedinog e-mail korisnika te domene
	for i in $domains; do
		if [ -d /var/spool/mail/$i ]; then
			for mail in $($IONICE find /var/spool/mail/$i -mindepth 1 -maxdepth 1 -type d); do
				echo "${SPACE2}- $(basename $mail)@$i: $($IONICE du -s $mail | awk '{print $1}')"
			done
		fi
	done
done

exit 0
