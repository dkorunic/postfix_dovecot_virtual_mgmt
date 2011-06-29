#!/bin/sh
# (C) Dinko Korunic, InfoMAR, 2011

LANG=C
PATH=/usr/kerberos/sbin:/usr/kerberos/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin

# brisanje virtualnih postfix/dovecot korisnika

VMDOM=/etc/postfix/virtual_domains	# Postfix virtdom mapping
VMBOX=/etc/postfix/virtual_mailbox	# Postfix virtmbox mapping
VMBOXQUOTA=/etc/postfix/virtual_quota	# Postfix virtmbox quota
VMSPOOL=/var/mail			# direktorij sa virt mdirovima
DPASS=/etc/dovecot-passwd		# Dovecot staticki passdb

# usage
if [ \( -z "$1" \) -o \( "$#" -lt 1 \) ]; then
	echo "Upotreba: $0 korisnik@domena [ korisnik@domena [ ... ] ]"
	exit 0
fi

# razumna zastita...
cd /
umask 022

# razne sistemske osnovne provjere
if [ ! -w "$VMDOM" ]; then
	echo "Sistemska greska: Ne mogu pisati u [$VMDOM] datoteku"
	exit 1
fi
if [ ! -w "$VMBOX" ]; then
	echo "Sistemska greska: Ne mogu pisati u [$VMBOX] datoteku"
	exit 1
fi
if [ ! -w "$VMBOXQUOTA" ]; then
	echo "Sistemska greska: Ne mogu pisati u [$VMBOXQUOTA] datoteku"
	exit 1
fi
if [ ! -w "$DPASS" ]; then
	echo "Sistemska greska: Ne mogu pisati u [$DPASS] datoteku"
	exit 1
fi
if [ ! -d "$VMSPOOL" ]; then
	echo "Sistemska greska: Ne postoji [$VMSPOOL] direktorij"
	exit 1
fi

while [ -n "$1" ]; do
	# sanitizacija unosa
	input=$(echo "$1" | sed -r -e 's/[^a-zA-Z0-9@._-]//g')

	# lowcaps
	input=$(echo "$input" | tr '[A-Z]' '[a-z]')

	# provjeri da li je unesen korisnik
	korisnik=$(echo $input | cut -d\@ -f1)
	if [ -z "$korisnik" ]; then
		echo "Neispravni argumenti: prazan korisnik"
		echo "Unijeli ste: [$input]"
		exit 1
	fi

	# provjera da li je unesena domena
	domena=$(echo $input | cut -d\@ -f2-)
	if [ -z "$domena" ]; then
		echo "Neispravni argumenti: prazna domena"
		echo "Unijeli ste: [$input]"
		exit 1
	fi

	# postoji li direktorij za korisnika
	if [ -d "$VMSPOOL/$domena/$korisnik" ]; then
		echo "Obrisao direktorij za korisnika [$input]"
		rm -rf "$VMSPOOL/$domena/$korisnik"
		rmdir "$VMSPOOL/$domena" > /dev/null 2>&1 || true
	fi

	# obrisi korisnika iz postfix vmbox
	echo "Obrisem korisnika iz [$VMBOX] datoteke"
	grep -v "^$input[[:space:]]" "$VMBOX" > "$VMBOX.$$"
	mv -f "$VMBOX.$$" "$VMBOX"
	postmap "$VMBOX" || \
		echo "Sistemska greska: postmap naredba nije uspjela"

	# obrisi korisnika iz postfix vmbox quota
	echo "Brisem korisnika [$input] iz [$VMBOXQUOTA] datoteke"
	grep -v "^$input[[:space:]]" "$VMBOXQUOTA" > "$VMBOXQUOTA.$$"
	mv -f "$VMBOXQUOTA.$$" "$VMBOXQUOTA"
	postmap "$VMBOXQUOTA" || \
		echo "Sistemska greska: postmap naredba nije uspjela"

	# obrisi korisnika iz dovecot password
	echo "Brisem korisnika iz [$DPASS] datoteke"
	grep -v "^$input:" "$DPASS" > "$DPASS.$$"
	mv -f "$DPASS.$$" "$DPASS"

	# postoji li domena u postfix virtdom konfiguraciji
	if [ ! -d "$VMSPOOL/$domena" ]; then
		echo "Brisem domenu iz [$VMDOM] datoteke"
		grep -v "^$domena$" "$VMDOM" > "$VMDOM.$$"
		mv -f "$VMDOM.$$" "$VMDOM"
	fi

	# reload postfixa
	postfix reload >/dev/null 2>&1 || \
		echo "Sistemska greska: postfix reload naredba nije uspjela"

	# finalna provjera
	redova_vmbox=$(grep -v '^[^#]' "$VMBOX" | wc -l)
	redova_dpass=$(grep -v '^[^#]' "$DPASS" | wc -l)
	if [ $redova_vmbox -ne $redova_dpass ]; then
		echo "Upozorenje: broj redova u [$VMBOX] datoteci ne odgovara"
		echo "Upozorenje: ... broju redova u [$DPASS] datoteci!"
		echo "Nastavljam s radom..."
	fi

	# iduci argument
	shift
done

exit 0
