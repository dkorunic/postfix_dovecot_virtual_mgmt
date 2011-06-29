#!/bin/sh
# (C) Dinko Korunic, InfoMAR, 2011

LANG=C
PATH=/usr/kerberos/sbin:/usr/kerberos/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin

# unosimo virtualne "korisnik@domena" korisnike u postfix/dovecot
#   sustav generira lozinku, dodaje u dovecot password database
#   te dodaje u postfix virtual mailboxove
#   opcionalno se stvara domenski poddirektorij za postfix

VMDOM=/etc/postfix/virtual_domains	# Postfix virtdom mapping
VMBOX=/etc/postfix/virtual_mailbox	# Postfix virtmbox mapping
VMBOXQUOTA=/etc/postfix/virtual_quota	# Postfix virtmbox quota
VMSPOOL=/var/mail			# direktorij sa virt mdirovima
VMAIL="5000:5000"			# staticki uid:gid za mailove
DPASS=/etc/dovecot-passwd		# Dovecot staticki passdb
QUOTA="419430400"			# default quota

# usage
if [ \( -z "$1" \) -o \( "$#" -lt 2 \) ]; then
	echo "Upotreba: $0 korisnik@domena lozinka"
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
if grep -q "^$input[[:space:]]" "$VMBOX"; then
	echo "Korisnik [$input] vec postoji u [$VMBOX] datoteci"
	exit 1
fi
if grep -q "^$input[[:space:]]" "$VMBOXQUOTA"; then
	echo "Korisnik [$input] vec postoji u [$VMBOXQUOTA] datoteci"
	exit 1
fi
if grep -q "^$input:" "$DPASS"; then
	echo "Korisnik [$input] vec postoji u [$DPASS] datoteci"
	exit 1
fi

# provjera da li je unesena domena
domena=$(echo $input | cut -d\@ -f2-)
if [ -z "$domena" ]; then
	echo "Neispravni argumenti: prazna domena"
	echo "Unijeli ste: [$input]"
	exit 1
fi

# da li se domena da resolvati
#if ! host -t soa "$domena." >/dev/null 2>&1; then
#	echo "Neispravni argumenti: nepostojeca domena [$domena]"
#	echo "Potrebno je prvo unijeti domenu u DNS"
#	exit 1
#fi

# postoji li domena u postfix virtdom konfiguraciji
if ! grep -q "^$domena$" "$VMDOM"; then
	echo "Dodajem domenu [$domena] u [$VMDOM] datoteku"
	echo "$domena" >> "$VMDOM"
fi

# postoji li direktorij za domenu
if [ ! -d "$VMSPOOL/$domena" ]; then
	echo "Napravio direktorij za domenu [$domena]"
	mkdir -p "$VMSPOOL/$domena"
	chown -Rh "$VMAIL" "$VMSPOOL/$domena"
	chmod u=rwxs,g=rxs,o= "$VMSPOOL/$domena"
fi

# postoji li direktorij za korisnika
if [ -d "$VMSPOOL/$domena/$korisnik" ]; then
	echo "Uh, postojao je direktorij za korisnika [$input]"
	echo "Molim, provjerite [$VMSPOOL/$domena/$korisnik]"
	echo "Nastavljam s radom..."
else
	echo "Napravio direktorij za korisnika [$input]"
	mkdir -p "$VMSPOOL/$domena/$korisnik"
	chown -Rh "$VMAIL" "$VMSPOOL/$domena/$korisnik"
	chmod u=rwxs,g=rxs,o= "$VMSPOOL/$domena/$korisnik"
fi

# dodaj korisnika u postfix vmbox
echo "Dodajem korisnika u [$VMBOX] datoteku"
echo -e "$input\t\t$domena/$korisnik/" >> "$VMBOX"
postmap "$VMBOX" || \
	echo "Sistemska greska: postmap naredba nije uspjela"

# dodaj korisnika u postfix vmbox quota
echo "Dodajem korisnika u [$VMBOXQUOTA] datoteku"
echo -e "$input\t\t$QUOTA" >> "$VMBOXQUOTA"
postmap "$VMBOXQUOTA" || \
	echo "Sistemska greska: postmap naredba nije uspjela"

# reload postfixa
postfix reload >/dev/null 2>&1 || \
	echo "Sistemska greska: postfix reload naredba nije uspjela"

# procitaj lozinku
lozinka="$2"
echo "Lozinka za korisnika [$input] je [$lozinka]"

# dodaj korisnika u dovecot password
echo "Dodajem korisnika u [$DPASS] datoteku"
lozinkamd5=$(mkpasswd -Hmd5 "$lozinka")
echo "$input:$lozinkamd5" >> "$DPASS"

# finalna provjera
redova_vmbox=$(grep -v '^[^#]' "$VMBOX" | wc -l)
redova_dpass=$(grep -v '^[^#]' "$DPASS" | wc -l)
if [ $redova_vmbox -ne $redova_dpass ]; then
	echo "Upozorenje: broj redova u [$VMBOX] datoteci ne odgovara"
	echo "Upozorenje: ... broju redova u [$DPASS] datoteci!"
	echo "Nastavljam s radom..."
fi

exit 0
