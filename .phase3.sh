#!/bin/bash

# Actually go pick up the variables from phase1 if they are not already set
[ "" == "${PITD}" ] && . ${1}
# From the first script we have inherited these values (all absolute paths)
# PITD			PostInstall Temp Dir
# FTPDIR		The 'pub' subdirectory on the FTP server
# MPOINT		Where the PostInstall ISO is/was mounted
# CDDEVICE		What device we found the PostInstall ISO in
# NIC1NAME		Name of the first configured Ethernet NIC
# NIC2NAME		Name of the second configured Ethernet NIC
# DETECTEDOS	Distribution/version of Linux we are using

[ "" == "${PITD}" ] && echo "DANGER: Error in collection of phase1 variables, contact developer/mentor." && exit 1

LOG="${PITD}/phase3.log"
echo "Phase two complete." | tee -a "${LOG}"
echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-" | tee -a "${LOG}"

if [ ${DONORMALCONFIG} -eq 1 ]; then   # Not indenting all of this, search for "DONORMALCONFIG" to find the end of the if block
echo "Setting up general stuff." | tee -a "${LOG}"

############################################################
# /etc/kickstart-release
############################################################
# Set in the first file, postinstall.sh
#echo "CentOS Lab server1 kickstart 1.0.0" >/etc/kickstart-release
cat /etc/kickstart-release >>/etc/issue

############################################################
# Random Number Generator daemon
############################################################
# See https://access.redhat.com/articles/1314933 , but in short I ran into
# times when the system could basically stall for no good reason and found
# the entropy pool was running low.  This is a simple way to give it a
# kick and keep processes from stalling.  The KB recommends some edits
# to the service's unit file but they don't appear to be required.
systemctl enable rngd.service &>>"${LOG}"
systemctl start rngd.service  &>>"${LOG}"

############################################################
# routes for testing
############################################################
echo "   Internal lab routes" | tee -a "${LOG}"
for i in `seq 1 9`; do
  echo "172.26.$i.0/24 via 172.26.0.20$i dev ${NIC2NAME}" >>/etc/sysconfig/network-scripts/route-Internal
done
for i in `seq 10 ${NUMOFWS}`; do
  echo "172.26.$i.0/24 via 172.26.0.2$i dev ${NIC2NAME}" >>/etc/sysconfig/network-scripts/route-Internal
done
#/etc/init.d/network restart

############################################################
# web server httpd
############################################################
echo "   httpd / Apache" | tee -a "${LOG}"
cd /var/www/html
ln -s ${FTPDIR}
systemctl enable httpd.service &>>"${LOG}"
systemctl start httpd.service &>>"${LOG}"

############################################################
# ftp server vsftpd
############################################################
echo "   vsftpd" | tee -a "${LOG}"
systemctl enable vsftpd.service &>>"${LOG}"
systemctl start vsftpd.service &>>"${LOG}"

############################################################
# dhcp server
############################################################
echo "   dhcpd" | tee -a "${LOG}"
sed -i.bak -e s/DHCPDARGS=/DHCPDARGS=${NIC2NAME}/ /etc/sysconfig/dhcpd
cat >/etc/dhcp/dhcpd.conf <<EOF
authoritative;
default-lease-time 14400;
max-lease-time 14400;
lease-file-name "/var/lib/dhcpd/dhcpd.leases";
ddns-update-style none;
option domain-name "example.com";
option subnet-mask 255.255.255.0;
option domain-name-servers 172.26.0.1;
option routers 172.26.0.1;

allow booting;
allow bootp;
option magic      code 208 = string;
option configfile code 209 = text;
option pathprefix code 210 = text;
option reboottime code 211 = unsigned integer 32;
class "pxeclients" {
   match if substring(option vendor-class-identifier, 0, 9) = "PXEClient";
   next-server 172.26.0.1;
   filename "pxelinux.0";
   # Reboot timeout after TFTP failure in seconds, 0 ~= forever
   option reboottime 30;
   # Magic was required for PXELINUX prior to v3.55
   option magic f1:00:74:7e;
   if exists dhcp-parameter-request-list {
     option dhcp-parameter-request-list = concat(option dhcp-parameter-request-list, d0, d1, d2, d3);
   }
}

subnet 172.26.0.0 netmask 255.255.255.0 {
        range 172.26.0.101 172.26.0.151;
}

host station1 {
        option host-name "station1";
        fixed-address 172.26.0.201;
        hardware ethernet 00:50:56:bb:75:ab;
}
host station2 {
        option host-name "station2";
        fixed-address 172.26.0.202;
        hardware ethernet 00:50:56:bb:55:3d;
}
EOF
systemctl enable dhcpd.service &>>"${LOG}"
systemctl start dhcpd.service &>>"${LOG}"

############################################################
# DNS server bind
############################################################
echo "   named / DNS" | tee -a "${LOG}"
# We no longer use a subdirectory for chroot'd bind config
# files.  See https://access.redhat.com/articles/770133 for details.
# 2015-03-23 - For the moment I am NOT using chroot'd bind anyway.  --Daniel_Johnson1
cat >/etc/named.conf <<EOF
options {
        directory "/var/named";
        # Forwarders are now set by scrape_dhcp_settings.sh
        #forwarders { 8.8.8.8; 8.8.4.4; };
        include "/etc/named.forwarders";
        listen-on { 127.0.0.1; 172.26.0/24; };
};
zone "example.com" IN {
        type master;
        file "db.example.com";
        allow-update { none; };
};
zone "0.26.172.in-addr.arpa" IN {
        type master;
        file "db.0.26.172.in-addr.arpa";
        allow-update { none; };
};
zone "4.2.3.0.5.1.0.2.1.1.e.d.7.0.d.f.ip6.arpa" IN {
		type master;
		file "db.4.2.3.0.5.1.0.2.1.1.e.d.7.0.d.f.ip6.arpa";
		allow-update {none; };
};
EOF
cat >/var/named/db.0.26.172.in-addr.arpa <<EOF
\$TTL 86400
@       IN      SOA     server1.example.com.    root.server1.example.com.       (
                                                20080915        ; Serial
                                                28800                   ; Refresh
                                                14400                   ; Retry
                                                3600000                 ; Expire
                                                86400 )                 ; Minimum


                        IN NS   server1.example.com.

1                       IN PTR  server1.example.com.
\$GENERATE 1-9  20\$    IN PTR  station\$.example.com.
\$GENERATE 10-${NUMOFWS}  2\$   IN PTR  station\$.example.com.

\$GENERATE 1-9   10\$     IN PTR  dhcp\$.example.com.
\$GENERATE 10-${NUMOFWS} 1\$      IN PTR  dhcp\$.example.com.
EOF
cat >/var/named/db.4.2.3.0.5.1.0.2.1.1.e.d.7.0.d.f.ip6.arpa <<EOF
;
; fd07:de11:2015:324::/64
;
; Zone file built with the IPv6 Reverse DNS zone builder
; http://rdns6.com/
;
\$TTL 1h ; Default TTL
\$ORIGIN 4.2.3.0.5.1.0.2.1.1.e.d.7.0.d.f.ip6.arpa.
@   IN   SOA   server1.example.com.   root.server1.example.com.   (
    2015032401 ; serial
    1h         ; slave refresh interval
    15m        ; slave retry interval
    1w         ; slave copy expire time
    1h         ; NXDOMAIN cache time
    )

;
; domain name servers
;
@ IN NS server1.example.com.


; IPv6 PTR entries
1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.4.2.3.0.5.1.0.2.1.1.e.d.7.0.d.f.ip6.arpa.    IN    PTR    server1.example.com.

EOF
cat >/var/named/db.example.com <<EOF
\$TTL 86400
@       1D IN SOA       server1.example.com.       root.server1.example.com.    (
                                20080916                ; serial (yyyymmdd)
                                3H                      ; refresh
                                15M                     ; retry
                                1W                      ; expiry
                                1D )                    ; minimum

                IN      NS      server1.example.com.

; station1      IN A    172.26.0.101
server1         IN A    172.26.0.1
server1         IN AAAA FD07:DE11:2015:0324::1
\$GENERATE 1-9 station\$  IN A    172.26.0.20\$
\$GENERATE 10-${NUMOFWS} station\$  IN A    172.26.0.2\$

\$GENERATE 1-9 dhcp\$    IN A    172.26.0.10\$
\$GENERATE 10-${NUMOFWS} dhcp\$  IN A    172.26.0.1\$
EOF
for i in `seq 1 9`; do
cat >/var/named/db.station$i.com <<EOF
\$TTL 86400
@       1D IN SOA       server1.example.com.       root.server1.example.com.    (
                                20080921                ; serial (yyyymmdd)
                                3H                      ; refresh
                                15M                     ; retry
                                1W                      ; expiry
                                1D )                    ; minimum

                IN      NS      station$i.com.
                IN      NS      station$i.example.com.
                IN      NS      server1.example.com.

                IN MX 10    station$i.com
                IN A    172.26.0.20$i
www             IN A    172.26.0.20$i
ns              IN A    172.26.0.20$i
EOF
done

for i in `seq 10 ${NUMOFWS}`; do
cat >/var/named/db.station$i.com <<EOF
\$TTL 86400
@       1D IN SOA       server1.example.com.       root.server1.example.com.    (
                                20080921                ; serial (yyyymmdd)
                                3H                      ; refresh
                                15M                     ; retry
                                1W                      ; expiry
                                1D )                    ; minimum

                IN      NS      station$i.com.
                IN      NS      station$i.example.com.
                IN      NS      server1.example.com.

                IN A    172.26.0.2$i
                IN MX 10 172.26.0.2$i
www             IN A    172.26.0.2$i
ns              IN A    172.26.0.2$i
EOF
done


for i in `seq 1 9`; do
cat >>/etc/named.conf <<EOF
zone "station$i.com" IN {
        type master;
        file "db.station$i.com";
        allow-update { none; };
        allow-transfer { 172.26.0.20$i; };
};
EOF
done

for i in `seq 10 ${NUMOFWS}`; do
cat >>/etc/named.conf <<EOF
zone "station$i.com" IN {
        type master;
        file "db.station$i.com";
        allow-update { none; };
        allow-transfer { 172.26.0.2$i; };
};
EOF
done

# We must have this file in place or BIND will not start.
if [ ! -f /etc/named.forwarders ]; then
  cat >>/etc/named.forwarders <<EOF
# Referenced from /etc/named.conf .  These are the external DNS servers
# we query when we don't have the answer.  They are set by scrape_dhcp_settings.sh .
# This particular file is a DEFAULT for use when we DID NOT GET VALUES from DHCP.
# The Google servers are not a good choice, but they are the closest thing we have
# to a 'global default' that /might/ work.
forwarders { 
  8.8.8.8;
  8.8.4.4;
};
EOF
fi

systemctl enable named.service &>>"${LOG}"
systemctl start named.service &>>"${LOG}"

############################################################
# tftp for pxe installing of stations
############################################################
echo "   tftpd" | tee -a "${LOG}"
# Enable the service within xinetd
#sed -r 's/(disable\s*=\s*)(yes)/\1no/' -i.bak /etc/xinetd.d/tftp
# ..as above but also configure it to have verbose logging (every tftp request gets logged this way)
sed -r -i.bak -e 's/(disable\s*=\s*)(yes)/\1no/'  -e 's/(server_args\s*)(=\s*-s)/\1= -v -s/' /etc/xinetd.d/tftp
# Make the xinetd service notice our changes
echo "Reloading xinetd.service"  &>>"${LOG}"
systemctl reload xinetd.service  &>>"${LOG}"
#####
# I had an issue where xinetd stopped and did not restart for some reason.
# Minor issue, since it works on reboot anyway.
sleep 2
echo "Checking xinetd.service and starting if still needed"  &>>"${LOG}"
( systemctl is-active xinetd.service || systemctl start xinetd.service ) &>>"${LOG}"

mkdir -p /var/lib/tftpboot/pxelinux.cfg &>>"${LOG}"

PXEDEFAULT=`echo "${ISOMOUNTDIRREL}" | cut -d "/" -f 1`

cat >/var/lib/tftpboot/pxelinux.cfg/default <<EOF
default menu.c32
prompt 0
timeout 300
ONTIMEOUT local
menu title #### PXE Boot Menu ####
 
label Q
  menu label ^Q) Quit PXE
  localboot 0

EOF

PXEMENUNUM=0
for full_path in `find ${FTPDIR} -name pxeboot -type d` ; do
	# Note that this loop is checking for the name of the subdirectory under 'pub'.
	# It is expected that each RHEL version will be in a different subdir of 'pub' directly
	# rather than something like 'pub/RHEL/7.0', 'pub/RHEL/7.1', etc.
	#echo $full_path
	# comp_name = extract the 5th field, delimiter /
	export comp_name=`echo $full_path|cut -d'/' -f5`
	mkdir -p /var/lib/tftpboot/$comp_name
	cp $full_path/* /var/lib/tftpboot/$comp_name/ &>>"${LOG}"

	let PXEMENUNUM++
	cat >>/var/lib/tftpboot/pxelinux.cfg/default <<EOF
label ${PXEMENUNUM}
  menu label ^${PXEMENUNUM}) ${comp_name}_manual_install
  kernel $comp_name/vmlinuz
  append initrd=${comp_name}/initrd.img root=live:http://server1.example.com/pub/${comp_name}/dvd/LiveOS/squashfs.img repo=http://server1.example.com/pub/${comp_name}/dvd/

EOF
	let PXEMENUNUM++
	cat >>/var/lib/tftpboot/pxelinux.cfg/default <<EOF
label ${PXEMENUNUM}
  menu label ^${PXEMENUNUM}) ${comp_name}_kickstart_install
  kernel $comp_name/vmlinuz
  append initrd=${comp_name}/initrd.img root=live:http://server1.example.com/pub/${comp_name}/dvd/LiveOS/squashfs.img repo=http://server1.example.com/pub/${comp_name}/dvd/ noipv6 ks=http://server1.example.com/pub/station_ks.cfg

EOF
done

cp -a /usr/share/syslinux/pxelinux.0 /usr/share/syslinux/menu.c32 /var/lib/tftpboot/ &>>"${LOG}"
restorecon -R /var/lib/tftpboot/ &>>"${LOG}"

############################################################
# ntp server - Disabled in favor of the RHEL 7-default chronyd
############################################################
echo "   NTP / Chrony" | tee -a "${LOG}"
# First we create a 'base' config that doesn't have any server addresses.
cat >/etc/chrony.conf.base <<EOF
# Servers specified at the BOTTOM of the file.

# Ignore stratum in source selection.
stratumweight 0
# Record the rate at which the system clock gains/losses time.
driftfile /var/lib/chrony/drift
# Enable kernel RTC synchronization.
rtcsync
# In first three updates step the system clock instead of slew
# if the adjustment is larger than 10 seconds.
makestep 10 3
# Allow NTP client access from local network.
allow 172.26.0.0/24
allow fd07:de11:2015:0324::/64
# Listen for commands only on localhost.
bindcmdaddress 127.0.0.1
bindcmdaddress ::1
# Serve time even if not synchronized to any NTP server.
local stratum 10
keyfile /etc/chrony.keys
# Specify the key used as password for chronyc.
commandkey 1
# Generate command key if missing.
generatecommandkey
# Disable logging of client accesses.
noclientlog
# Send a message to syslog if a clock adjustment is larger than 0.5 seconds.
logchange 0.5
logdir /var/log/chrony
#log measurements statistics tracking

EOF
chattr +i /etc/chrony.conf.base
# Now we append some sane(?) default servers and use that as our initial config.
cp /etc/chrony.conf.base /etc/chrony.conf
if [ ${DETECTEDOS} -lt 10 ]; then
  NTPPOOL="rhel."
elif [ ${DETECTEDOS} -lt 20 ]; then
  NTPPOOL="centos."
else
  NTPPOOL=""
fi
cat >>/etc/chrony.conf <<EOF
# Default values in case your upstream DHCP server doesn't provide NTP server addresses
server ntp1.us.dell.com iburst
server ntp2.us.dell.com iburst
server 0.${NTPPOOL}pool.ntp.org iburst
server 1.${NTPPOOL}pool.ntp.org iburst
server 2.${NTPPOOL}pool.ntp.org iburst
server 3.${NTPPOOL}pool.ntp.org iburst

EOF
chattr +i /etc/chrony.conf
# The script "scrape_dhcp_settings.sh" will use the base config with any
# servers specified by our upstream DHCP server.

systemctl enable chronyd.service &>>"${LOG}"
systemctl start  chronyd.service &>>"${LOG}"

############################################################
# NIS server - Deprecated, commented out 2015-07-01
############################################################

############################################################
# making some users
############################################################
echo "   Lab Users" | tee -a "${LOG}"
# password flag
# Adding the group here, admittedly 'early'.  We set up Samba
# access for the "userX" logins, not "guestX".
groupadd smbuser &>>"${LOG}"

# This directory is also referenced later
mkdir /home/server1 &>>"${LOG}"
# Was 50, dropped to 11, then made into a variable NUMOFWS
for i in `seq -w 1 ${NUMOFWS}`; do
  # password flag
  # This block is not creating a group per user.  For now we don't care.
  useradd -g users -u 20$i -d /home/server1/guest$i guest$i  &>>"${LOG}"
  echo "P@ssw0rd" | passwd --stdin guest$i  &>>"${LOG}"
done

############################################################
# Create Certificate Authority CA
############################################################
echo "   Local CA" | tee -a "${LOG}"
# clean-up
# rm /etc/pki/CA/private/cakey.pem /etc/pki/CA/cacert.pem /var/ftp/pub/materials/cacert.pem
# password flag
(umask 077;openssl genrsa -passout pass:cacertpass -out /etc/pki/CA/private/cakey.pem -des3 2048)  &>>"${LOG}"
# password flag
openssl req -new -x509 -passin pass:cacertpass -key /etc/pki/CA/private/cakey.pem -days 3650 >/etc/pki/CA/cacert.pem <<EOF  2>>"${LOG}"
US
Texas
Round Rock
Dell

server1.example.com
root@server1.example.com
EOF

mkdir -p ${FTPDIR}/materials
rm -f ${FTPDIR}/materials/cacert.pem
cp /etc/pki/CA/cacert.pem ${FTPDIR}/materials/cacert.pem

touch /etc/pki/CA/index.txt
echo "01" > /etc/pki/CA/serial
touch /etc/pki/CA/cacert.srl
echo "01" > /etc/pki/CA/cacert.srl

# was "/etc/openldap/cacerts/" in all three references on the next two lines
cp /etc/pki/CA/cacert.pem /etc/openldap/certs/
ln -s /etc/openldap/certs/cacert.pem /etc/openldap/certs/`openssl x509 -hash -noout -in /etc/openldap/certs/cacert.pem`.0 &>>"${LOG}"
# http://server1.example.com/pub/materials/cacert.pem

############################################################
# Create student station web server certs
############################################################

mkdir -p ${FTPDIR}/materials/certs &>>"${LOG}"

# Don't use the -w switch in seq here
for i in `seq 1 ${NUMOFWS}`; do
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "${FTPDIR}/materials/certs/geek${i}.key"  -out "${FTPDIR}/materials/certs/geek${i}.crt" <<EOF &>>"${LOG}"
US
Texas
Round Rock
Dell

geek${i}.example.com
root@station${i}.example.com
EOF
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "${FTPDIR}/materials/certs/nerd${i}.key"  -out "${FTPDIR}/materials/certs/nerd${i}.crt" <<EOF &>>"${LOG}"
US
Texas
Round Rock
Dell

nerd${i}.example.com
root@station${i}.example.com
EOF
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "${FTPDIR}/materials/certs/dweeb${i}.key" -out "${FTPDIR}/materials/certs/dweeb${i}.crt" <<EOF &>>"${LOG}"
US
Texas
Round Rock
Dell

dweeb${i}.example.com
root@station${i}.example.com
EOF
done

############################################################
# Create ldap server certs
############################################################
echo "   LDAP" | tee -a "${LOG}"
# to test tls  [Still valid?]
# ldapsearch -H 'ldap://server1.example.com' -D 'uid=guest01,ou=People,dc=example,dc=com' -x -W -b "dc=example,dc=com" -ZZ -d1

openssl req -new -x509 -nodes -out /etc/openldap/certs/cert.pem -keyout /etc/openldap/certs/priv.pem -days 365 <<EOF &>>"${LOG}"
US
Texas
Round Rock
Dell
Linux In A Box lab
server1.example.com
root@server1.example.com
EOF


############################################################
# ldap server
############################################################
if [ ${DOLDAPCONFIG} -eq 1 ]; then  # Not indenting the block, search for "#End of DOLDAPCONFIG"

echo "Starting the new LDAP stuff" &>>"${LOG}"

# Certificate generated earlier
#openssl req -new -x509 -nodes -out /etc/openldap/certs/cert.pem -keyout /etc/openldap/certs/priv.pem -days 365 &>>"${LOG}"
chown ldap:ldap /etc/openldap/certs/* &>>"${LOG}"
chmod 600 /etc/openldap/certs/priv.pem &>>"${LOG}"
(cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG; slaptest) &>>"${LOG}"
chown ldap:ldap /var/lib/ldap/* &>>"${LOG}"
systemctl enable slapd.service &>>"${LOG}"
systemctl start slapd.service &>>"${LOG}"
ldapadd -Y EXTERNAL -H ldapi:/// -D "cn=config" -f /etc/openldap/schema/cosine.ldif &>>"${LOG}"
ldapadd -Y EXTERNAL -H ldapi:/// -D "cn=config" -f /etc/openldap/schema/nis.ldif &>>"${LOG}"
cp /etc/openldap/certs/cert.pem /var/www/html/pub/materials/ &>>"${LOG}"

# To change the olcRootPW entry below, run this command and copy the output.
#    slappasswd -s redhat -n > /etc/openldap/passwd 
# For now the hash below is from 'redhat'.

# Be careful with this redirect or it will dump the output to the log instead of the LDIF file
cat <<EOF >/etc/openldap/changes.ldif 2>>"${LOG}"
dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcSuffix
olcSuffix: dc=example,dc=com

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcRootDN
olcRootDN: cn=Manager,dc=example,dc=com

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcRootPW
olcRootPW: {SSHA}5ya72uj/eu56gNRYC1l/tW2XJBsO7/RJ

dn: cn=config
changetype: modify
replace: olcTLSCertificateFile
olcTLSCertificateFile: /etc/openldap/certs/cert.pem

dn: cn=config
changetype: modify
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/openldap/certs/priv.pem

dn: cn=config
changetype: modify
replace: olcLogLevel
olcLogLevel: -1

dn: olcDatabase={1}monitor,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" read by dn.base="cn=Manager,dc=example,dc=com" read by * none
EOF

ldapmodify -Y EXTERNAL -H ldapi:/// -f /etc/openldap/changes.ldif &>>"${LOG}"

# Be careful with this redirect or it will dump the output to the log instead of the LDIF file
cat <<EOF >/etc/openldap/base.ldif 2>>"${LOG}"
dn: dc=example,dc=com
dc: example
objectClass: top
objectClass: domain

dn: ou=People,dc=example,dc=com
ou: People
objectClass: top
objectClass: organizationalUnit

dn: ou=Group,dc=example,dc=com
ou: Group
objectClass: top
objectClass: organizationalUnit
EOF

ldapadd -x -w redhat -D cn=Manager,dc=example,dc=com -f /etc/openldap/base.ldif &>>"${LOG}"

pushd /usr/share/migrationtools &>>"${LOG}"
#Edit the migrate_common.ph file and replace in the following lines:
# $DEFAULT_MAIL_DOMAIN = "example.com";
# $DEFAULT_BASE = "dc=example,dc=com";
sed -e s/padl/example/ -e s/ou=Group/ou=Groups/ migrate_common.ph -i.bak  &>>"${LOG}"

# Note, this should get all of guest01 through guest##.
grep "guest" /etc/passwd > passwd 2>>"${LOG}"
./migrate_passwd.pl passwd users.ldif &>>"${LOG}"
ldapadd -x -w redhat -D cn=Manager,dc=example,dc=com -f users.ldif &>>"${LOG}"
grep "guest" /etc/group > group 2>>"${LOG}"
./migrate_group.pl group groups.ldif &>>"${LOG}"
ldapadd -x -w redhat -D cn=Manager,dc=example,dc=com -f groups.ldif &>>"${LOG}"
popd &>>"${LOG}"

echo "Testing the new LDAP stuff" &>>"${LOG}"
ldapsearch -x cn=guest01 -b dc=example,dc=com &>>"${LOG}"

echo "Finished the new LDAP stuff" &>>"${LOG}"

else #DOLDAPCONFIG
  echo "LDAP configuration skipped by command argument." | tee -a "${LOG}"
fi #End of DOLDAPCONFIG main block

############################################################
# kerberos
############################################################
if [ ${DOKERBEROSCONFIG} -eq 1 ]; then # Not indenting the block, search for "#End of DOKERBEROSCONFIG"
echo "   Kerberos" | tee -a "${LOG}"

# Uncomment the 'master_key_type' line, allowing for leading whitespace before the #
#sed -i  '/master_key_type/s/^ *#//' /var/kerberos/krb5kdc/kdc.conf &>>"${LOG}"
# Aahh, screw it.  There's a better way.

cat <<EOF | patch -b -d /var/kerberos/krb5kdc &>>"${LOG}"
--- kdc.conf_orig       2014-03-11 19:22:53.000000000 +0000
+++ kdc.conf    2015-07-01 02:03:50.212004811 +0000
@@ -5,5 +5,6 @@
 [realms]
  EXAMPLE.COM = {
-  #master_key_type = aes256-cts
+  master_key_type = aes256-cts
+  default_principal_flags = +preauth
   acl_file = /var/kerberos/krb5kdc/kadm5.acl
   dict_file = /usr/share/dict/words
EOF

[ ! -f /etc/krb5.conf_orig ] && cp -a /etc/krb5.conf /etc/krb5.conf_orig
# This was originally done with a patch, but it's as large as the end-result
# file and couldn't be directly edited.  Back to nuke-and-replace.
cat <<EOF >/etc/krb5.conf 2>>"${LOG}"
[logging]
 default = FILE:/var/log/krb5libs.log
 kdc = FILE:/var/log/krb5kdc.log
 admin_server = FILE:/var/log/kadmind.log

[libdefaults]
 dns_lookup_realm = false
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true
 rdns = false
 default_realm = EXAMPLE.COM
 default_ccache_name = KEYRING:persistent:%{uid}

 default_realm = EXAMPLE.COM
 dns_lookup_kdc = false
[realms]
 EXAMPLE.COM = {
  kdc = server1.example.com
  admin_server = server1.example.com
 }

[domain_realm]
 .example.com = EXAMPLE.COM
 example.com = EXAMPLE.COM
EOF


# /var/kerberos/krb5kdc/kadm5.acl ...we're already just using example.com

# This step can appear to hang if the entropy pool is low.  This is what
# led me to install and enable rngd.
echo "Kernel entropy pool value before: `cat /proc/sys/kernel/random/entropy_avail`" &>>"${LOG}"
echo -e "redhat\nredhat" | kdb5_util create -s -r EXAMPLE.COM &>>"${LOG}"
echo "Kernel entropy pool value after: `cat /proc/sys/kernel/random/entropy_avail`" &>>"${LOG}"

systemctl enable krb5kdc &>>"${LOG}"
systemctl enable kadmin &>>"${LOG}"
systemctl start krb5kdc &>>"${LOG}"
systemctl start kadmin &>>"${LOG}"


# The user 'guest01' here was originally 'ldapuser'
KADMINCMDS="${PITD}/kadmin.local_cmds"
cat <<EOF > "${KADMINCMDS}"
addprinc root/admin
redhat
redhat

addprinc -randkey host/server1.example.com
addprinc -randkey nfs/server1.example.com
EOF
for i in `seq 1 ${NUMOFWS}`; do
  cat <<EOF >> "${KADMINCMDS}"
addprinc -randkey host/station${i}.example.com
addprinc -randkey nfs/station${i}.example.com
EOF
done
cat <<EOF >> "${KADMINCMDS}"

# These have to run after all of the addprinc's.
ktadd host/server1.example.com
ktadd nfs/server1.example.com
EOF
for i in `seq 1 ${NUMOFWS}`; do
  cat <<EOF >> "${KADMINCMDS}"
ktadd host/station${i}.example.com
ktadd nfs/station${i}.example.com
EOF
done
cat <<EOF >> "${KADMINCMDS}"

ktadd -k /var/kerberos/krb5kdc/kadm5.keytab kadmin/admin kadmin/changepw
quit
EOF

kadmin.local <"${KADMINCMDS}" &>>"${LOG}"

cp /etc/krb5.keytab ${FTPDIR}/materials/krb5.keytab
chmod a+r ${FTPDIR}/materials/krb5.keytab &>>"${LOG}"

for NUM in `seq -w -s " " 1 ${NUMOFWS}`; do
  echo -e "redhat\nredhat" | kadmin.local -q "addprinc guest${NUM}" &>>"${LOG}"
done

cat <<EOF | patch -b -d /etc/ssh &>>"${LOG}"
--- ssh_config_orig     2014-03-19 20:50:07.000000000 +0000
+++ ssh_config  2015-07-01 03:16:39.423873305 +0000
@@ -51,4 +51,5 @@
 Host *
        GSSAPIAuthentication yes
+       GSSAPIDelegateCredentials yes
 # If this option is set to yes then remote X11 clients will have full access
 # to the original X11 display. As virtually no X11 client supports the untrusted
EOF

# Be careful with the log redirection here, or it will write the text to
# the log instead of the XML file.
cat <<EOF >/etc/firewalld/services/kerberos.xml 2>>"${LOG}"
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>Kerberos</short>
  <description>Kerberos network authentication protocol server</description>
  <port protocol="tcp" port="88"/>
  <port protocol="udp" port="88"/>
  <port protocol="tcp" port="749"/>
</service>
EOF

authconfig --enablekrb5 --update &>>"${LOG}"

cat <<EOF | patch -b -d /etc &>>"${LOG}"
--- idmapd.conf_orig	2014-01-26 12:33:44.000000000 +0000
+++ idmapd.conf	2015-08-13 20:33:47.151534977 +0000
@@ -3,5 +3,5 @@
 # The following should be set to the local NFSv4 domain name
 # The default is the host's DNS domain name.
-#Domain = local.domain.edu
+Domain = example.com
 
 # The following is a comma-separated list of Kerberos realm
@@ -18,6 +18,6 @@
 [Mapping]
 
-#Nobody-User = nobody
-#Nobody-Group = nobody
+Nobody-User = nfsnobody
+Nobody-Group = nfsnobody
 
 [Translation]
@@ -29,5 +29,5 @@
 # New methods may be defined and inserted in the list.
 # The default is "nsswitch".
-#Method = nsswitch
+Method = nsswitch
 
 # Optional.  This is a comma-separated, ordered list of
EOF


cp /etc/krb5.conf   ${FTPDIR}/materials/ &>>"${LOG}"
cp /etc/idmapd.conf ${FTPDIR}/materials/ &>>"${LOG}"

else #DOKERBEROSCONFIG
  echo "Kerberos configuration skipped by command argument." | tee -a "${LOG}"
fi #End of DOKERBEROSCONFIG main block


############################################################
# nfs server
############################################################
 echo "   NFS" | tee -a "${LOG}"
# This directory (/home/server1) should have been created earlier but just in case do it again.
mkdir /home/server1 &>>"${LOG}"
mkdir -p /exports/nfssecure &>>"${LOG}"
mkdir -p /exports/nfs{1..3} &>>"${LOG}"
chown -R root:users /exports/ &>>"${LOG}"
chmod -R 1777 /exports/ &>>"${LOG}"

cat >/etc/exports <<EOF
${FTPDIR}        *(ro,sync)
/home/server1       *(rw,sync)
/exports/nfssecure          *.example.com(sec=krb5,rw,fsid=0)
/exports/nfs1             *(rw,sync)
/exports/nfs2			  *(rw,sync)
/exports/nfs3             *(rw,sync)
EOF

cat >>/etc/sysconfig/nfs <<EOF
###  Begin section added by Dell RHIAB postinstall.sh

RQUOTAD_PORT=875
LOCKD_TCPPORT=32803
LOCKD_UDPPORT=32769
# I had tried to be extra careful by using "+=" when setting these, but that
# doesn't work now that systemd is parsing this file instead of bash.
STATDARG=" -p 662 "
# We are specifying the value that is already in /etc/services
# in RHEL v7.0
RPCMOUNTDOPTS=" -p 20048 " 
# Kerberos-related
SECURE_NFS=yes
###  End section added by Dell LIAB postinstall.sh
EOF

cat >> /etc/sysctl.d/20-nfs_nlm.conf <<EOF
fs.nfs.nlm_tcpport=32803
fs.nfs.nlm_udpport=32769
EOF

systemctl enable nfs.target &>>"${LOG}"
systemctl enable nfs-server.service &>>"${LOG}"
systemctl enable nfs-secure-server.service &>>"${LOG}"
systemctl start nfs.target &>>"${LOG}"
systemctl start nfs-server.service &>>"${LOG}"
systemctl start nfs-secure-server.service &>>"${LOG}"

############################################################
# Samba
############################################################
echo "   Samba" | tee -a "${LOG}"

mkdir -p /samba/{public,restricted,misc} &>>"${LOG}"
chmod -R 0777 /samba &>>"${LOG}"
semanage fcontext -a -t samba_share_t '/samba(/.*)?' &>>"${LOG}"
restorecon -Rv /samba &>>"${LOG}"
setsebool -P samba_enable_home_dirs on &>>"${LOG}"
[ ! -f /etc/samba/smb.conf.orig ] && cp -a /etc/samba/smb.conf /etc/samba/smb.conf.orig &>>"${LOG}"

cat <<EOF 1>>/etc/samba/smb.conf 2>>"${LOG}"
#Samba config for Red Hat in a box
#
[global]
        workgroup = WORKGROUP
        server string = Samba Server Version %v
        log file = /var/log/samba/log.%m
        max log size = 100
        security = user
        passdb backend = tdbsam
[homes]
        comment = Home Directories
        browseable = no
        writeable = yes
[public]
        comment = Public Files
        path = /samba/public
        public = yes
[restricted]
        comment = restricted share
        path = /samba/restricted
        browseable = no
        writeable = yes
        write list = @smbuser
[misc]
		comment = Misc Share
		path - /samba/misc
		public = yes
EOF

systemctl enable smb.service nmb.service &>>"${LOG}"
systemctl start smb.service nmb.service &>>"${LOG}"

############################################################
# iSCSI targets
############################################################
echo "   iSCSI" | tee -a "${LOG}"
# http://www.linuxjournal.com/content/creating-software-backed-iscsi-targets-red-hat-enterprise-linux-6
# 25k * 4k = 100m, adjust sizes to suit your needs
# 25k * 1k = 24m
# This section still needs to be corrected/updated for RHEL v7.x

mkdir -p /var/lib/target &>>"${LOG}"

#systemctl disable targetd.service &>>"${LOG}"
systemctl disable target.service &>>"${LOG}"
#systemctl stop targetd.service &>>"${LOG}"
systemctl stop target.service &>>"${LOG}"
rm /etc/target/iscsi_batch_setup.tmp &>/dev/null

# Doing a quick command to 'prime' the preferences file at /root/.targetcli/prefs.bin
echo "clearconfig confirm=True" > /etc/target/iscsi_batch_setup.tmp
echo "saveconfig" >> /etc/target/iscsi_batch_setup.tmp
echo "exit" >> /etc/target/iscsi_batch_setup.tmp
echo "Running initial 'priming' commands for iSCSI targetcli." &>>"${LOG}"
# DANGER DANGER
# The "targetcli" command is a Python script that calls code from /usr/lib/python2.7/site-packages/configshell/shell.py .
# That module in turn *only* loads the "readline" module if it detects that its output is a TTY.
# Normal shell piping and redirections of stdout make that test fail, which breaks things badly
# because targetcli *requires* that "readline" work.  Using "script" is an elegant work-around to this.
script -c "targetcli < /etc/target/iscsi_batch_setup.tmp" -a "${LOG}" >/dev/null
echo "Clearing iSCSI configuration for real this time." &>>"${LOG}"
script -c "targetcli < /etc/target/iscsi_batch_setup.tmp" -a "${LOG}" >/dev/null

rm /etc/target/iscsi_batch_setup.tmp &>/dev/null
echo "set global auto_add_mapped_luns=false" >> /etc/target/iscsi_batch_setup.tmp
for i in `seq -w 1 ${NUMOFWS}`; do
  # The "backstores" line takes care of creating the files.  Nice!
  #dd if=/dev/zero of=/var/lib/target/station$i bs=1k count=25k &>>"${LOG}"
  cat >>/etc/target/iscsi_batch_setup.tmp <<EOF
  backstores/fileio create station${i} /var/lib/target/station${i} 25M
  iscsi/ create iqn.2014-12.example.com:station${i}-target
  iscsi/iqn.2014-12.example.com:station${i}-target/tpg1/portals/ create
  iscsi/iqn.2014-12.example.com:station${i}-target/tpg1/luns/ create /backstores/fileio/station${i}
  iscsi/iqn.2014-12.example.com:station${i}-target/tpg1/acls/ create iqn.2014-12.example.com:station${i} add_mapped_luns=true
EOF
# Removed from the above section
#  iscsi/iqn.2014-12.example.com:station${i}-target/tpg1/ set attribute authentication=0
#  iscsi/iqn.2014-12.example.com:station${i}-target/tpg1/ set attribute generate_node_acls=1
done

echo "saveconfig" >> /etc/target/iscsi_batch_setup.tmp
echo "exit" >> /etc/target/iscsi_batch_setup.tmp

echo "Setting desired iSCSI configuration." &>>"${LOG}"
script -c "targetcli < /etc/target/iscsi_batch_setup.tmp" -a "${LOG}" >/dev/null

restorecon -R /var/lib/target

#systemctl enable targetd.service &>>"${LOG}"
systemctl enable target.service &>>"${LOG}"
#systemctl start targetd.service &>>"${LOG}"
systemctl start target.service &>>"${LOG}"



############################################################
# Student logins on the server
############################################################
echo "   Create student users" | tee -a "${LOG}"
for N in 1 2 3 4 5; do
  useradd -m -G smbuser user${N} &>>"${LOG}"
  echo "P@ssw0rd" | passwd --stdin user${N} &>>"${LOG}"
  echo -e "P@ssw0rd\nP@ssw0rd" | smbpasswd -a user${N} &>>"${LOG}"
done
  useradd student &>>"${LOG}"
  echo "P@ssw0rd" | passwd --stdin student &>>"${LOG}"
  echo -e "P@ssw0rd\nP@ssw0rd" | smbpasswd -a student &>>"${LOG}"
  for i in {student,user1,user2,user3,user4,user5}; do mkdir /home/$i/files; done
  for i in {student,user1,user2,user3,user4,user5}; do touch /home/$i/files/file{1..10}.txt; done
  echo "big brother is watching" | tee /home/*/files/file{1..10}.txt
  chmod -R 0660 /home/*/files
  for i in {student,user1,user2,user3,user4,user5}; do chown -R $i: /home/$i/files;done

############################################################
# final steps
############################################################
echo "   Miscellaneous" | tee -a "${LOG}"

# Ensure the manpage database is current, especially after adding the _selinux pages.
mandb &>>"${LOG}"

mkdir -p ${FTPDIR}/plusrepo &>>"${LOG}"
mkdir -p ${FTPDIR}/materials &>>"${LOG}"

# Create some simple links to remove versions from their names
(
	cd ${FTPDIR}/materials
	ln -s `find ${ISOMOUNTDIR} -iname "lftp*x86_64.rpm" | head -n 1` lftp.rpm &>>"${LOG}"
	ln -s `find ${ISOMOUNTDIR} -iname "elinks*x86_64.rpm" | head -n 1` elinks.rpm &>>"${LOG}"
	ln -s `find . -iname "sl*x86_64.rpm" | head -n 1` sl.rpm &>>"${LOG}"
)

# Make a new tarball containing elinks
ELT=`mktemp -d`
cp `find ${ISOMOUNTDIR} -iname "elinks*x86_64.rpm" | head -n 1` "${ELT}/elinks.rpm" &>>"${LOG}"
pushd "${ELT}" &>>"${LOG}"
tar -czf file.tar.gz elinks.rpm &>>"${LOG}"
popd &>>"${LOG}"
mv "${ELT}/file.tar.gz" "${FTPDIR}/" &>>"${LOG}"
rm "${ELT}" -rf  &>>"${LOG}"

(
  cd ${FTPDIR}
  # Obviously if/when we make a new bundle of v7.x files, this date
  # will need to be adjusted.  Each of these not only provides a new
  # subdirectory with a pre-created YUM repo, but also a
  # distribution-specific repo file in 'materials'.
  tar -xzf centos7.3_partial_20170111.tgz &>>"${LOG}"
  # And now we make a symlink to what should be the only one we want.
  cd materials
  case ${DETECTEDOS} in
    10) # CentOS v7.0
      ln -s server1-centos-updates.repo server1-updates.repo &>>"${LOG}"
      ;;
    12) # CentOS v7.2
      ln -s server1-centos-updates.repo server1-updates.repo &>>"${LOG}"
      ;;
  esac
)

cat >${FTPDIR}/materials/server1.repo <<EOF
[server1]
name=${YUMDISTRO_NAME}
baseurl=ftp://server1.example.com/pub/${ISOMOUNTDIRREL}
enabled=1
gpgcheck=1
gpgkey=${YUMGPGPATH}
# Excluding elinks and lftp so students have to add them via an RPM file
exclude=elinks lftp

[plusrepo]
name=Additional Packages
baseurl=ftp://server1.example.com/pub/plusrepo
enabled=0
gpgcheck=0
EOF

#cat >/etc/yum.repos.d/rhel6.5.repo <<EOF
#[rhel6.5]
#name=Red Hat Enterprise Linux 6.5
#baseurl=ftp://server1/pub/rhel6.5/Server
#enabled=1
#gpgcheck=1
#gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
#EOF

mkdir -m 700 -p /root/.ssh
ssh-keygen -q -t rsa -N '' -f /root/.ssh/id_rsa &>>"${LOG}"
cp /root/.ssh/id_rsa.pub "${FTPDIR}/materials/" &>>"${LOG}"
echo "UseDNS no" >>/etc/ssh/sshd_config
# less readable, but left as a note. & replaces the matched text
# sed -e 's/GSSAPIAuthentication yes/#&/' -i /etc/ssh/sshd_config
sed -e 's/#GSSAPIAuthentication no/GSSAPIAuthentication no/' -e 's/GSSAPIAuthentication yes/#GSSAPIAuthentication yes/' -i /etc/ssh/sshd_config
# add ip_conntrack_ftp to iptables modules loaded
sed -e 's/IPTABLES_MODULES="/&ip_conntrack_ftp /' -i.bak /etc/sysconfig/iptables-config

echo "server1" >/var/www/html/index.html

# password flag
useradd -g users -g 100 localuser &>>"${LOG}"
echo "P@ssw0rd" | passwd --stdin localuser &>>"${LOG}"

rpm --import ${YUMGPGPATH} &>>"${LOG}"
cat >"${FTPDIR}/materials/user-script.sh"<<EOF
#!/bin/bash
echo "Hello World"
EOF

cat >"${FTPDIR}/materials/breakme1.sh"<<EOF
#!/bin/bash
clear
echo $1$yRy7E5q7$dv4CJaRDsyhsbJBPeH/L81 | passwd --stdin root
echo "******************************"
echo
echo "Root Password has been changed"
echo "******************************"
echo
echo "System will reboot in 5 seconds"
echo "*******************************"
sleep 5
reboot
EOF
chmod 777 "${FTPDIR}/materials/breakme1.sh"

# Adjust the user_agent reported by 'yum' to clear some internal Dell EMC
# firewall/server/proxy restrictions.  Being a bit lazy here, if we ever
# have more than one version of Python present this command will fail as
# the glob is no longer a single result.
patch -d /usr/lib/python* -p0 <<EOF &>>"${LOG}"
--- site-packages/yum/__init__.py.orig	2015-09-11 08:44:44.000000000 +0000
+++ site-packages/yum/__init__.py	2016-10-19 22:14:28.085566509 +0000
@@ -109,7 +109,9 @@
 # so that other API users can easily add to it if they want.
 #  Don't do it at init time, or we'll get multiple additions if you create
 # multiple YumBase() objects.
-default_grabber.opts.user_agent += " yum/" + __version__
+# Changed by RHIAB starting 2016-10-19 to address Dell EMC internal access
+# restrictions.  Identified by David.Easterly@dell.com .
+default_grabber.opts.user_agent += "Mozilla 5.0 (X11; Linux x86_64; rv:10.0) Gecko/20100101 Firefox/10.0" 
 
 
 class _YumPreBaseConf:
EOF

############################################################
# Firewall configuration
############################################################
echo "   Firewall rules" | tee -a "${LOG}"
# Firewall setup
echo "Firewall rules start" &>>"${LOG}"
firewall-cmd --permanent --zone=external --change-interface=${NIC1NAME} &>>"${LOG}"
firewall-cmd --permanent --zone=internal --change-interface=${NIC2NAME} &>>"${LOG}"
# External services
firewall-cmd --permanent --zone=external --add-service=ssh &>>"${LOG}"
firewall-cmd --permanent --zone=external --add-service=ftp &>>"${LOG}"
firewall-cmd --permanent --zone=external --add-service=http &>>"${LOG}"
# Internal services
firewall-cmd --permanent --zone=internal --add-service=ssh &>>"${LOG}"
firewall-cmd --permanent --zone=internal --add-service=dhcp &>>"${LOG}"
firewall-cmd --permanent --zone=internal --add-service=dhcpv6 &>>"${LOG}"
firewall-cmd --permanent --zone=internal --add-service=dns &>>"${LOG}"
firewall-cmd --permanent --zone=internal --add-service=ftp &>>"${LOG}"
firewall-cmd --permanent --zone=internal --add-service=tftp &>>"${LOG}"
firewall-cmd --permanent --zone=internal --add-service=http &>>"${LOG}"
firewall-cmd --permanent --zone=internal --add-service=https &>>"${LOG}"
firewall-cmd --permanent --zone=internal --add-service=ldap &>>"${LOG}"
firewall-cmd --permanent --zone=internal --add-service=ldaps &>>"${LOG}"
# The kerberos service is custom, and defined in the Kerberos section above
firewall-cmd --permanent --zone=internal --add-service=kerberos &>>"${LOG}"
firewall-cmd --permanent --zone=internal --add-service=samba &>>"${LOG}"
firewall-cmd --permanent --zone=internal --add-service=ntp &>>"${LOG}"
# iSCSI is not a pre-defined service
firewall-cmd --permanent --zone=internal --add-port=3260/tcp &>>"${LOG}"
# NFS is going to be a pain the rear.  Thanks to Aaron_Southerland for sorting this out.
# NFS v4
firewall-cmd --permanent --zone=internal --add-port=2049/tcp &>>"${LOG}"
firewall-cmd --permanent --zone=internal --add-port=2049/udp &>>"${LOG}"
# NFS v3
firewall-cmd --permanent --zone=internal --add-port=111/tcp &>>"${LOG}"
firewall-cmd --permanent --zone=internal --add-port=111/udp &>>"${LOG}"
firewall-cmd --permanent --zone=internal --add-port=20048/tcp &>>"${LOG}"
firewall-cmd --permanent --zone=internal --add-port=20048/udp &>>"${LOG}"
firewall-cmd --permanent --zone=internal --add-port=875/tcp &>>"${LOG}"
firewall-cmd --permanent --zone=internal --add-port=875/udp &>>"${LOG}"
firewall-cmd --permanent --zone=internal --add-port=32803/tcp &>>"${LOG}"
firewall-cmd --permanent --zone=internal --add-port=32769/udp &>>"${LOG}"
firewall-cmd --permanent --zone=internal --add-port=662/tcp &>>"${LOG}"
firewall-cmd --permanent --zone=internal --add-port=662/udp &>>"${LOG}"
# End NFS stuff
# Make the 'permanent' changes effective without reboot
#firewall-cmd --reload &>>"${LOG}"
# For some reason the simple --reload usually fails to adjust the
# per-interface zone configuration.  Let's be more thorough.
systemctl restart firewalld.service &>>"${LOG}"
# Give that time to actually load the rules
sleep 10
iptables -nvL &>>"${PITD}/iptables_nvL"
firewall-cmd --list-all-zones &>>"${PITD}/firewall-cmd_list-all-zones"
echo "Firewall rules done" &>>"${LOG}"

else # DONORMALCONFIG     if block
  echo "Not applying normal configuration." | tee -a "${LOG}"
fi # End of DONORMALCONFIG main if block

# The -o forces overwriting of existing files.
pushd ${FTPDIR}/materials &>/dev/null
unzip -o ../extras.zip &>>"${LOG}"
popd &>/dev/null

chown root:root ${FTPDIR}/ -R &>/dev/null

cp ${FTPDIR}/materials/shakespeare.txt /samba/public &>>"${LOG}"
cp ${FTPDIR}/materials/madcow.wav ${FTPDIR}/materials/Paradise_Lost.txt /samba/restricted &>>"${LOG}"
cp ${FTPDIR}/materials/Steam_Its_Generation_and_Use.txt /home/server1 &>>"${LOG}"
cp ${FTPDIR}/materials/War_and_Peace.txt /exports/nfssecure &>>"${LOG}"
cp ${FTPDIR}/materials/Calculus_Made_Easy.pdf /exports/nfs1 &>>"${LOG}"
cp ${FTPDIR}/materials/Alices_Adventures_in_Wonderland.txt /exports/nfs3 &>>"${LOG}"
cp ${FTPDIR}/materials/Moby_Dick.txt /exports/nfs2 &>>"${LOG}"
cp ${FTPDIR}/materials/The_History_Of_The_Decline_And_Fall_Of_The_Roman_Empire.txt /samba/misc &>>"${LOG}"
tar -xzf ${FTPDIR}/materials/ring.tgz -C /exports/nfssecure &>>"${LOG}"

if [ ${DONORMALCONFIG} -eq 1 ]; then
  `echo "Y2hjb24gLXQgYWRtaW5faG9tZV90IC92YXIvZnRwL3B1Yi9tYXRlcmlhbHMvc2hha2VzcGVhcmUudHh0Cg==" | base64 -d`
  SCRATCH=`mktemp`
  cat <<EOF | base64 -d > ${SCRATCH}
IyEvYmluL2Jhc2gKCkZpbmRXcml0YWJsZVJhbmRvbURpcigpIHsKICAjIFRoZSB2YXJpYWJsZSAi
RldSRCIgd2lsbCBiZSBzZXQgdG8gYSByYW5kb21seSBzZWxlY3RlZCBkaXJlY3RvcnkgaW4gd2hp
Y2gKICAjIHdlIGNhbiBjcmVhdGUgZmlsZXMuICBXZSB0cnkgdG8gYXZvaWQgdG91Y2h5IHBsYWNl
cyBsaWtlIC9zeXMsIHByaW50ZXIKICAjIHNwb29scywgZXRjLiAgSWYgeW91IHByb3ZpZGUgYSBm
aWxlbmFtZSB3ZSB3aWxsIGVuc3VyZSBpdCBkb2VzIG5vdCBjcmVhdGUKICAjIGEgY29uZmxpY3Qg
YW5kIHJldHVybiAiRldSREYiIHdpdGggdGhlIGZ1bGwgcGF0aCtmaWxlbmFtZS4KICBfX0ZXUkRT
Q1JBVENIPWBta3RlbXBgCiAgX19GV1JERklMRU5BTUU9IiR7MTotX19GV1JERklMRU5BTUVURVNU
fSIKICB3aGlsZSBbIC1mICIke19fRldSRFNDUkFUQ0h9IiBdOyBkbwogICAgIyBUaGUgc3RydWN0
dXJlIGlzICAgIGZpbmQgIFtSb290UGF0aHNdICBbRGlyZWN0b3JpZXNPbmx5XSAgW1Vud2FudGVk
TGlzdF0gIFtQcnVuZV0gIFtMb2dpY2FsT3JdIFtEaXJlY3Rvcmllc09ubHldIFtOb3RdW1Vud2Fu
dGVkTGlzdF0gIFtQcmludF0KICAgICMgWWVzIGl0J3MgYSBiaXQgbG9uZyBidXQgaXQgZG9lcyBp
biBvbmUgZWZmaWNpZW50IGNvbW1hbmQgd2hhdCB3b3VsZCBoYXZlIG90aGVyd2lzZSBuZWVkZWQg
cmVnZXgsIHRlbXAgZmlsZXMsIG9yIG90aGVyIG5hc3R5IGFwcHJvYWNoZXMuCiAgICBGV1JEPWBm
aW5kIC9ib290IC9ldGMgL2hvbWUgL29wdCAvcm9vdCAvdXNyIC92YXIgLXR5cGUgZCBcKCAtaW5h
bWUgImRldiIgLW8gLWluYW1lICJ1ZGV2IiAtbyAtaW5hbWUgInNwb29sIiAtbyAtaW5hbWUgInRt
cCIgLW8gLWluYW1lICJsb2NrIiAtbyAtaW5hbWUgIiouZCIgXCkgLXBydW5lIC1vIC10eXBlIGQg
ISBcKCAtaW5hbWUgImRldiIgLW8gLWluYW1lICJ1ZGV2IiAtbyAtaW5hbWUgInNwb29sIiAtbyAt
aW5hbWUgInRtcCIgLW8gLWluYW1lICJsb2NrIiAtbyAtaW5hbWUgIiouZCIgXCkgLXByaW50IDI+
L2Rldi9udWxsIHwgc29ydCAtUiB8IGhlYWQgLW4gMWAKICAgIEZXUkRGPSIke0ZXUkR9LyR7X19G
V1JERklMRU5BTUV9IgogICAgIyBBbmQgb2YgY291cnNlLCBjYW4gd2UgYWN0dWFsbHkgd3JpdGUg
dG8gdGhpcywgYW5kIG91ciB0YXJnZXQgZG9lc24ndCBleGlzdD8KICAgIHRvdWNoICIke0ZXUkR9
Ly5fX0ZXUkRURVNUIiAyPi9kZXYvbnVsbCAmJiBybSAiJHtGV1JEfS8uX19GV1JEVEVTVCIgJiYg
WyAhIC1mICR7RldSREZ9IF0gJiYgcm0gIiR7X19GV1JEU0NSQVRDSH0iCiAgZG9uZQp9CgojIENy
ZWF0ZSBzb21lIHRoaW5ncyBmb3Igc3R1ZGVudHMgdG8gc2VhcmNoIGZvci4KRmluZFdyaXRhYmxl
UmFuZG9tRGlyICIubXVsZGVyIjsgZWNobyAiVGhlIHRydXRoIGlzIExPT0sgT1VUIEJFSElORCBZ
T1UhIiA+ICIke0ZXUkRGfSIKRmluZFdyaXRhYmxlUmFuZG9tRGlyICIuMzQzIjsgZWNobyAiR3Jl
ZXRpbmdzISAgSSBhbSB0aGUgTW9uaXRvciBvZiBJbnN0YWxsYXRpb24gMDQuICBJIGFtIDM0MyBH
dWlsdHkgU3BhcmsuICBTb21lb25lIGhhcyByZWxlYXNlZCB0aGUgRmxvb2QuICBNeSBmdW5jdGlv
biBpcyB0byBwcmV2ZW50IGl0IGZyb20gbGVhdmluZyB0aGlzIEluc3RhbGxhdGlvbiwgYnV0IEkg
cmVxdWlyZSB5b3VyIGFzc2lzdGFuY2UuICBDb21lLiAgVGhpcyB3YXkuLiIgPiAiJHtGV1JERn0i
CkZpbmRXcml0YWJsZVJhbmRvbURpciAiLmJvbmVzIjsgZWNobyAiRGFtbml0LCBKaW0sIEknbSBh
IHN5c2FkbWluIG5vdCBhIHNlYXJjaCBlbmdpbmUhIiA+ICIke0ZXUkRGfSIKRmluZFdyaXRhYmxl
UmFuZG9tRGlyICIua2hhbiI7IGVjaG8gIkFoLCBLaXJrLCBteSBvbGQgZnJpZW5kLiAgRG8geW91
IGtub3cgdGhlIEtsaW5nb24gcHJvdmVyYiB0aGF0IHRlbGxzIHVzIHJldmVuZ2UgaXMgYSBkaXNo
IGJlc3Qgc2VydmVkIGNvbGQ/ICBJdCBpcyB2ZXJ5IGNvbGQgaW4gc3BhY2UhIiA+ICIke0ZXUkRG
fSIKRmluZFdyaXRhYmxlUmFuZG9tRGlyICIuYmlsYm8iOyBlY2hvICJJIGRvbid0IGtub3cgaGFs
ZiBvZiB5b3UgaGFsZiBhcyB3ZWxsIGFzIEkgc2hvdWxkIGxpa2U7IGFuZCBJIGxpa2UgbGVzcyB0
aGFuIGhhbGYgb2YgeW91IGhhbGYgYXMgd2VsbCBhcyB5b3UgZGVzZXJ2ZS4iID4gIiR7RldSREZ9
IgpGaW5kV3JpdGFibGVSYW5kb21EaXIgIi5yYXJlIjsgZWNobyAiQ29tbW9uIHNlbnNlIGlzIHNv
IHJhcmUgaXQgc2hvdWxkIGJlIGNvbnNpZGVyZWQgYSBzdXBlci1wb3dlci4iID4gIiR7RldSREZ9
IgpGaW5kV3JpdGFibGVSYW5kb21EaXIgImpva2VyIjsgZWNobyAiSGF2ZSB5b3UgZXZlciBkYW5j
ZWQgd2l0aCB0aGUgZGV2aWwgaW4gdGhlIHBhbGUgbW9vbmxpZ2h0PyIgPiAiJHtGV1JERn0iCkZp
bmRXcml0YWJsZVJhbmRvbURpciAic2lza28iOyBlY2hvICJTby4uLiBJIGxpZWQuICBJIGNoZWF0
ZWQuICBJIGJyaWJlZCBtZW4gdG8gY292ZXIgdGhlIGNyaW1lcyBvZiBvdGhlciBtZW4uICBJIGFt
IGFuIGFjY2Vzc29yeSB0byBtdXJkZXIuICBCdXQgdGhlIG1vc3QgZGFtbmluZyB0aGluZyBvZiBh
bGwuLi4gIEkgdGhpbmsgSSBjYW4gbGl2ZSB3aXRoIGl0LiAgQW5kIGlmIEkgaGFkIHRvIGRvIGl0
IGFsbCBvdmVyIGFnYWluIC0gSSB3b3VsZC4gIEdhcmFrIHdhcyByaWdodCBhYm91dCBvbmUgdGhp
bmc6IGEgZ3VpbHR5IGNvbnNjaWVuY2UgaXMgYSBzbWFsbCBwcmljZSB0byBwYXkgZm9yIHRoZSBz
YWZldHkgb2YgdGhlIEFscGhhIFF1YWRyYW50LiAgU28gSSB3aWxsIGxlYXJuIHRvIGxpdmUgd2l0
aCBpdC4uLiAgQmVjYXVzZSBJIGNhbiBsaXZlIHdpdGggaXQuLi4gIEkgY2FuIGxpdmUgd2l0aCBp
dC4uLiAgQ29tcHV0ZXIgLSBlcmFzZSB0aGF0IGVudGlyZSBwZXJzb25hbCBsb2cuIiA+ICIke0ZX
UkRGfSIKRmluZFdyaXRhYmxlUmFuZG9tRGlyICJib3JvbWlyIjsgZWNobyAiT25lIGRvZXMgbm90
IHNpbXBseSB3YWxrIGludG8gTW9yZG9yLiBJIHRzIEJsYWNrIEdhdGVzIGFyZSBndWFyZGVkIGJ5
IG1vcmUgdGhhbiBqdXN0IE9yY3MuICBUaGVyZSBpcyBldmlsIHRoZXJlIHRoYXQgZG9lcyBub3Qg
c2xlZXAsIGFuZCB0aGUgR3JlYXQgRXllIGlzIGV2ZXIgd2F0Y2hmdWwuICBJdCBpcyBhIGJhcnJl
biB3YXN0ZWxhbmQsIHJpZGRsZWQgd2l0aCBmaXJlIGFuZCBhc2ggYW5kIGR1c3QsIHRoZSB2ZXJ5
IGFpciB5b3UgYnJlYXRoZSBpcyBhIHBvaXNvbm91cyBmdW1lLiAgTm90IHdpdGggdGVuIHRob3Vz
YW5kIG1lbiBjb3VsZCB5b3UgZG8gdGhpcy4gIEl0IGlzIGZvbGx5LiIgPiAiJHtGV1JERn0iCkZp
bmRXcml0YWJsZVJhbmRvbURpciAidmFkZXIiOyBlY2hvICJZb3UgbWF5IGRpc3BlbnNlIHdpdGgg
dGhlIHBsZWFzYW50cmllcywgQ29tbWFuZGVyLiAgSSBhbSBoZXJlIHRvIHB1dCB5b3UgYmFjayBv
biBzY2hlZHVsZS4iID4gIiR7RldSREZ9IgpGaW5kV3JpdGFibGVSYW5kb21EaXIgIlJ2QiI7IGVj
aG8gIkZyZWVsYW5jZXIgcG93ZXJzLCBhY3RpdmF0ZSEiID4gIiR7RldSREZ9IgpGaW5kV3JpdGFi
bGVSYW5kb21EaXIgImdhbmRhbGYiOyBlY2hvICJZb3UhICBTaGFsbCBub3QhICBQYXNzISIgPiAi
JHtGV1JERn0iCkZpbmRXcml0YWJsZVJhbmRvbURpciAiaHVsayI7IGVjaG8gIkh1bGsgU01BU0gh
IiA+ICIke0ZXUkRGfSIKRmluZFdyaXRhYmxlUmFuZG9tRGlyICJzcG9jayI7IGVjaG8gIlRoZSBu
ZWVkcyBvZiB0aGUgbWFueSBvdXR3ZWlnaCB0aGUgbmVlZHMgb2YgdGhlIGZldywgb3IgdGhlIG9u
ZS4iID4gIiR7RldSREZ9IgpGaW5kV3JpdGFibGVSYW5kb21EaXIgInBvdHRlciI7IGVjaG8gIldl
J3ZlIGFsbCBnb3QgYm90aCBsaWdodCBhbmQgZGFyayBpbnNpZGUgdXMuICBXaGF0IG1hdHRlcnMg
dGhhdCB0aGUgcGFydCB3ZSBjaG9vc2UgdG8gYWN0IG9uLiAgVGhhdOKAmXMgd2hvIHdlIHJlYWxs
eSBhcmUuIiA+ICIke0ZXUkRGfSIKRmluZFdyaXRhYmxlUmFuZG9tRGlyICIubGVnbyI7IGVjaG8g
IllvdSBrbm93LCBJIGRvbid0IHdhbnQgdG8gc3BvaWwgdGhlIHBhcnR5IGJ1dCwgZG9lcyBhbnlv
bmUgbm90aWNlIHRoYXQgd2UncmUgc3R1Y2sgaW4gdGhlIG1pZGRsZSBvZiB0aGUgb2NlYW4gb24g
dGhpcyBjb3VjaD8gRG8geW91IGtub3cgd2hhdCBraW5kIG9mIHN1bmJ1cm4gSSdtIGdvaW5nIHRv
IGdldD8gTm9uZSwgJ2NhdXNlIEknbSBjb3ZlcmVkIGluIGxhdGV4LCBidXQgeW91IGd1eXMgYXJl
IGdvaW5nIHRvIGdldCBzZXJpb3VzbHkgZnJpZWQuIEkgbWVhbiBpdCdzIG5vdCBsaWtlIGEuLi4g
bGlrZSBhIGJpZyBnaWdhbnRpYyBzaGlwIGlzIGp1c3QgZ29pbmcgdG8gY29tZSBvdXQgb2Ygbm93
aGVyZSBhbmQgc2F2ZSBVUyBieSBnb3NoLiIgPiAiJHtGV1JERn0iCkZpbmRXcml0YWJsZVJhbmRv
bURpciAiLnN1cGVybmF0dXJhbCI7IGVjaG8gIlRoYXQgaXMgZXhhY3RseSB3aHkgb3VyIGxpdmVz
IHN1Y2suICBJIG1lYW4sY29tZSBvbiwgd2UgaHVudCBtb25zdGVycyEgIFdoYXQgdGhlIGhlbGw/
ICBJIG1lYW4sIG5vcm1hbCBwZW9wbGUsIHRoZXkgc2VlIGEgbW9uc3RlciwgYW5kIHRoZXkgcnVu
LiAgQnV0IG5vdCB1cywgbm8sIG5vLCBubywgd2Ugc2VhcmNoIG91dCB0aGluZ3MgdGhhdCB3YW50
IHRvIGtpbGwgdXMuICBPciBlYXQgdXMhICBZb3Uga25vdyB3aG8gZG9lcyB0aGF0PyAgQ3Jhenkg
cGVvcGxlISAgV2UgYXJlIGluc2FuZSEgIFlvdSBrbm93LCBhbmQgdGhlbiB0aGVyZSdzIHRoZSBi
YWQgZGluZXIgZm9vZCBhbmQgdGhlbiB0aGUgc2tlZXZ5IG1vdGVsIHJvb21zIGFuZCB0aGVuIHRo
ZSB0cnVjay1zdG9wIHdhaXRyZXNzIHdpdGggdGhlIGJpemFycmUgcmFzaC4gIEkgbWVhbix3aG8g
d2FudHMgdGhpcyBsaWZlLCBTYW0/ICBTZXJpb3VzbHk/ICBEbyB5b3UgYWN0dWFsbHkgbGlrZSBi
ZWluZyBzdHVjayBpbiBhIGNhciB3aXRoIG1lIGVpZ2h0IGhvdXJzIGEgZGF5LCBldmVyeSBzaW5n
bGUgZGF5PyAgSSBkb24ndCB0aGluayBzbyEgIEkgbWVhbiwgSSBkcml2ZSB0b28gZmFzdC4gIEFu
ZCBJIGxpc3RlbiB0byB0aGUgc2FtZSBmaXZlIGFsYnVtcyBvdmVyIGFuZCBvdmVyIGFuZCBvdmVy
IGFnYWluLCBhbmQgSSBzaW5nIGFsb25nLiAgSSdtIGFubm95aW5nLCBJIGtub3cgdGhhdC4gIEFu
ZCB5b3UsIHlvdSdyZSBnYXNzeSEgIFlvdSBlYXQgaGFsZiBhIGJ1cnJpdG8sIGFuZCB5b3UgZ2V0
IHRveGljISAgSSBtZWFuLHlvdSBrbm93IHdoYXQ/ICBZb3UgY2FuIGZvcmdldCBpdC4gIFN0YXkg
YXdheSBmcm9tIG1lIFNhbSwgT0s/ICBCZWNhdXNlIEkgYW0gZG9uZSB3aXRoIGl0LiAgSSdtIGRv
bmUgd2l0aCB0aGUgbW9uc3RlcnMgYW5kIHRoZSBoZWxsaG91bmRzIGFuZCB0aGUgZ2hvc3Qgc2lj
a25lc3MgYW5kIHRoZSBkYW1uIGFwb2NhbHlwc2UuICBJJ20gb3V0LiAgSSdtIGRvbmUuICBRdWl0
LiIgPiAiJHtGV1JERn0iCgpGaW5kV3JpdGFibGVSYW5kb21EaXIgImdhcmFrIjsgY2F0ID4gIiR7
RldSREZ9IiA8PEVPRgpTaXNrbzogV2hvJ3Mgd2F0Y2hpbmcgVG9sYXI/wqAKR2FyYWs6IEkndmUg
bG9ja2VkIGhpbSBpbiBoaXMgcXVhcnRlcnMuICBJJ3ZlIGFsc28gbGVmdCBoaW0gd2l0aCB0aGUg
ZGlzdGluY3QgaW1wcmVzc2lvbiB0aGF0IGlmIGhlIGF0dGVtcHRzIHRvIGZvcmNlIHRoZSBkb29y
IG9wZW4sIGl0IG1heSBleHBsb2RlLsKgClNpc2tvOiBJIGhvcGUgdGhhdCdzIGp1c3QgYW4gaW1w
cmVzc2lvbi7CoApHYXJhazogSXQncyBiZXN0IG5vdCB0byBkd2VsbCBvbiBzdWNoIG1pbnV0aWFl
CkVPRgpGaW5kV3JpdGFibGVSYW5kb21EaXIgInJpbmciOyBjYXQgPiAiJHtGV1JERn0iIDw8RU9G
CkFzaCBuYXpnIGR1cmJhdHVsw7trCmFzaCBuYXpnIGdpbWJhdHVsCmFzaCBuYXpnIHRocmFrYXR1
bMO7awphZ2ggYnVyenVtLWlzaGkga3JpbXBhdHVsCkVPRgoKIyBBdCB0aGUgcmVxdWVzdCBvZiBB
YXJvbl9Tb3V0aGVybGFuZApGaW5kV3JpdGFibGVSYW5kb21EaXIgIi5kb25nbGUiOyBlY2hvICJE
YW1uaXQsIFdlcyEiID4gIiR7RldSREZ9IgoKIyBSZW1vdmUgY2x1ZXMgYWJvdXQgd2hhdCB3ZSBy
ZWNlbnRseSBkaWQKRldSRD0iIgpGV1JERj0iIgojIERlbGV0ZSBvdXJzZWx2ZXMKcm0gJHtTQ1JB
VENIfQo=
EOF
  . ${SCRATCH}
fi

# The extra flags help keep the /usr/local structure from being damaged by (future) poorly-made TGZs.
tar -xzf ${FTPDIR}/ASCII_Art.tgz --no-overwrite-dir --no-selinux -C /  &>>"${LOG}"
AACT=`mktemp`
# Preserve any existing crontab
crontab -l > ${AACT} 2>>"${LOG}"
if ! grep -q "rotate_issue.sh" ${AACT}; then
  echo "*/5 * * * * /usr/local/bin/rotate_issue.sh &>/dev/null" >> ${AACT}
  crontab ${AACT}  &>>"${LOG}"
fi
rm ${AACT} &>/dev/null

# From now on, carefully take our DHCP-assigned DNS servers and use the values
# for our 'forwarder' configuration.
SDS=`mktemp`
crontab -l > "${SDS}" 2>>"${LOG}"
if ! grep -q "scrape_dhcp_settings.sh" "${SDS}"; then
  echo "@reboot    /usr/local/sbin/scrape_dhcp_settings.sh &>/dev/null" >> "${SDS}"
  echo "57 * * * * /usr/local/sbin/scrape_dhcp_settings.sh &>/dev/null" >> "${SDS}"
  crontab "${SDS}"  &>>"${LOG}"
fi
rm "${SDS}" &>/dev/null
/usr/local/sbin/scrape_dhcp_settings.sh &>>"${LOG}"

# Make sure this database is current
/etc/cron.daily/mlocate &>>"${LOG}"


`echo "bG9nZ2VyIElcJ20gbWFraW5nIGEgbm90ZSBoZXJlOiBIVUdFIFNVQ0NFU1MK" | base64 -d`

echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-" | tee -a "${LOG}"
echo "Creating troubleshooting log bundle.  Please IGNORE ANY ERRORS you see." | tee -a "${LOG}"
history &> "${PITD}/history.txt"
pushd /tmp &>/dev/null
ls -alF ${PITD} >> "${LOG}"
set >> "${LOG}"
# While this captures the output of the actual sosreport command, there are
# some kernel/dmesg lines about /dev/fd0 that end up appearing on the
# console anyway.  Hence the 'please ignore' above.
sosreport --tmp-dir "${PITD}" --batch &>> "${LOG}"
# Using the ZIP format just to let less-technical students have a prayer of
# opening it on their own.(like they will ever look at the logs)
rm /root/RHIAB_PostInstall_troubleshooting.zip &>/dev/null
zip -9r /root/RHIAB_PostInstall_troubleshooting.zip ${PITD}/* &>/dev/null
# This makes it easier for Linux-newbies to pull the file for me if they have problems.
cp -f /root/RHIAB_PostInstall_troubleshooting.zip ${FTPDIR}/
popd &>/dev/null

EXTIP4=`ip -4 address show ${NIC1NAME} | grep "inet " | cut -d " " -f 6 | cut -d "/" -f 1`
if [ ! -z ${EXTIP4} ]; then
  echo "Log bundle available at:"
  echo "   http://${EXTIP4}/pub/RHIAB_PostInstall_troubleshooting.zip"
else
  # I considered falling back to IPv6 here, but if the student/user is enough
  # of a newbie to need this level of hand-holding there isn't much chance
  # they'll figure out how to reach a link-local IPv6 URL in their browser.
  # I have no way of knowing what their interface name would be anyway.
  echo "I don't have an external IPv4 address right now, but the log was"
  echo "generated anyway.  It's in both /root and ${FTPDIR}."
fi

echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
echo ""
echo ""
echo "All done."
echo ""
echo ""
echo "Now we are going to reboot the server!"
echo ""
`echo "bG9nZ2VyIEl0XCdzIGhhcmQgdG8gb3ZlcnN0YXRlIG15IHNhdGlzZmFjdGlvbi4K" | base64 -d`
sleep 10
reboot
