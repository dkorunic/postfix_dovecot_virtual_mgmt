#!/bin/sh
# (C) Dinko Korunic, InfoMAR, 2011

LANG=C
PATH=/usr/kerberos/sbin:/usr/kerberos/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin

# mijenjamo lozinku za "korisnik@domena" korisnika u dovecotu
#   sustav generira lozinku, dodaje u dovecot password database

VMBOX=/etc/postfix/virtual_mailbox	# Postfix virtmbox mapping
DPASS=/etc/dovecot-passwd		# Dovecot staticki passdb

# usage
if [ \( -z "$1" \) -o \( "$#" -lt 2 \) ]; then
	echo "Upotreba: $0 korisnik@domena lozinka"
	exit 0
fi

# razumna zastita...
cd /
umask 022

if [ ! -w "$DPASS" ]; then
	echo "Sistemska greska: Ne mogu pisati u [$DPASS] datoteku"
	exit 1
fi

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

# provjeri postoji li vec korisnik
if ! grep -q "^$input:" "$DPASS"; then
	echo "Korisnik [$input] ne postoji u [$DPASS] datoteci"
	exit 1
fi

# provjera da li je unesena domena
domena=$(echo $input | cut -d\@ -f2-)
if [ -z "$domena" ]; then
	echo "Neispravni argumenti: prazna domena"
	echo "Unijeli ste: [$input]"
	exit 1
fi

# procitaj lozinku
lozinka="$2"
echo "Lozinka za korisnika [$input] je [$lozinka]"

# dodaj korisnika u dovecot password
echo "Mijenjam lozinku za korisnika [$input] u [$DPASS] datoteci"
lozinkamd5=$(mkpasswd -Hmd5 "$lozinka")
sed -i -e "s,^$input:.*$,$input:$lozinkamd5,g" "$DPASS"

# finalna provjera
redova_vmbox=$(grep -v '^[^#]' "$VMBOX" | wc -l)
redova_dpass=$(grep -v '^[^#]' "$DPASS" | wc -l)
if [ $redova_vmbox -ne $redova_dpass ]; then
	echo "Upozorenje: broj redova u [$VMBOX] datoteci ne odgovara"
	echo "Upozorenje: ... broju redova u [$DPASS] datoteci!"
	echo "Nastavljam s radom..."
fi

exit 0
