#!/bin/sh
# (C) Dinko Korunic, InfoMAR, 2011

LANG=C
PATH=/usr/kerberos/sbin:/usr/kerberos/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin

VMALIAS=/etc/postfix/virtual_aliases      # Postfix virtual aliases

# usage
if [ \( -z "$1" \) -o \( "$#" -lt 2 \) ]; then
        echo "Upotreba: $0 korisnik@domena korisnik2@domena2 [ ... ]"
        exit 0
fi

# razumna zastita...
cd /
umask 022

# razne sistemske osnovne provjere
if [ ! -w "$VMALIAS" ]; then
        echo "Sistemska greska: Ne mogu pisati u [$VMALIAS] datoteku"
        exit 1
fi

# sanitizacija unosa
input=$(echo "$1" | sed -r -e 's/[^a-zA-Z0-9@._-]//g')

# lowcaps
input=$(echo "$input" | tr '[A-Z]' '[a-z]')

# originalno odrediste
aliassrc="$input"

if grep -q "^$input[[:space:]]" "$VMALIAS"; then
	aliasorigarry=$(awk "BEGIN {FS=\"[ \\t:,]\"} /^$input[[:space:]]/ { for (i=2; i<=NF; i++) { print \$i } }" "$VMALIAS")
	aliasdest=$(echo $aliasorigarry | tr ' ' ',')
fi

# iduci argument
shift

# obrada samih alias destinacija
while [ -n "$1" ]; do
	# sanitizacija unosa
	input=$(echo "$1" | sed -r -e 's/[^a-zA-Z0-9@._-]//g')

	# lowcaps
	input=$(echo "$input" | tr '[A-Z]' '[a-z]')

	# zbrajanje destinacija i provjera duplikata
	if [ -n "$aliasdest" ]; then
		duplicate="false"
		for i in $aliasorigarry; do
			if [ "$input" = "$i" ]; then
				duplicate="true"
			fi
		done
		if [ "$duplicate" = "false" ]; then
			aliasorigarry="$aliasorigarry $input"
			aliasdest="$aliasdest,$input"
		fi
	else
		aliasorigarry="$input"
		aliasdest="$input"
	fi

	# iduci argument
	shift
done

grep -v "^$aliassrc[[:space:]]" "$VMALIAS" > "$VMALIAS.$$" && \
	echo -e "$aliassrc\t\t$aliasdest" >> "$VMALIAS.$$" && \
	mv "$VMALIAS.$$" "$VMALIAS"
rm -f "$VMALIAS.$$"
postmap "$VMALIAS" || \
	echo "Sistemska greska: postmap naredba nije uspjela"

exit 0
