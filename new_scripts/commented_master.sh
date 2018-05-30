
#!/bin/bash

### SET UP INITIAL VARIABLES ###

LIABVERSION="1.2.0"
LIABRELEASE="2018-05-29"

# Banner lines
BL1="[====/ Linux In A Box Setup Script, version $LIABVERSION"
BL2="   //  $LIABRELEASE for CentOS 7.x x86_64"
BL3="  //"
BL4=" //"
KICKSTARTRELEASE="LIAB server v$LIABVERSION"

# Absolute path to the 'pub' directory for the FTP server
FTPDIR=/var/ftp/pub

showBanner(){
echo ""
echo "${BL1}"; echo "${BL2}"; echo "${BL3}"; echo "${BL4}"
echo ""
}
showBanner


# Daniel_Johnson1@dell.com      Aaron_Southerland@dell.com
# This script was made to automate the initial setup of the Linux In
# A Box lab server.  With RHEL7 we cannot use floppy-based kickstart scripts,
# and changes to how network devices are enumerated creates a challenge
# that I do not believe can be solved before or during installation in any
# supportable, reliable way.
#
# Thus this PostInstall script, which used to just handle a few things
# too large for kickstarting, will have to do *everything*.  The user is
# expected to have created a VM using the default settings in the RHEL 7.2
# ISO, assigned a root password (we suggest "password"), and either
# skipped creating a normal user or created one with a name that won't
# cause any conflicts later.  Basically just take defaults and stay out of
# our way.  :)
#

# *** with the new updates, this should not be an issue *** 
am_I_sourced () {
  # From  http://stackoverflow.com/a/12396228
  if [ "${FUNCNAME[1]}" = source ]; then
    #echo "I am being sourced, this filename is ${BASH_SOURCE[0]} and my caller script/shell name was $0"
    return 0
  else
    #echo "I am not being sourced, my script/shell name was $0"
    return 1
  fi
}

# *** we should not need this section either *** 
check4Source(){
# Lazyness - If we are being sourced, I need to remove all the 'exit's and substitute
# something that won't log you out.  But I'd rather not spend time on that right now, so...
if am_I_sourced ; then
  echo "ERROR: This script must be called directly rather than being 'sourced'."
  # See, can't use 'exit' here
  return 0
fi
}

mustBeRoot(){
[ 0 -ne $UID ] && echo "ERROR: This MUST be run as root!  Try again." && exit 1
}


# *** or this section *** 
mustUseAbsolutePath(){
if am_I_sourced ; then
  MPOINT=`dirname ${BASH_SOURCE[0]}`
else
  MPOINT=`dirname $0`
fi

[ "/" != "${MPOINT:0:1}" ] && echo "ERROR: You must call this script using an absolute path, not a relative path." && echo "       Example:  /mnt/postinstall.sh" && exit 1
}


# *** or this ***
dontRunFromPWD(){
# I'm not sure that this would be a problem I can't bypass but why take chances?
pwd | grep -q "^${MPOINT}" && echo "ERROR: You must NOT call this script from the mount point directory itself." && echo "       Use something like    cd /root; ${0}" && exit 1
}


# *** will be calling this from a git folder in /root home folder ***
checkForISO9660(){
# "What on earth is this?"  We had an issue when someone specified iso9660 as the mounting filesystem type.
# It messed with the length and case-sensitivity of filenames.  If this long nasty name survives, the others will too.
[ ! -f ${MPOINT}/.fsflag.Aa-Bb-Cc_Dd_Ee_Ff.1.2.3.4.5.6.7.9.10.11.12.13.14.15.16.17.18.19.20.21.22.23.24.25.txt ] && echo "ERROR: ISO mounted with the WRONG filesystem, names are corrupt." && echo "       Re-mount without specifying a filesystem type." && exit 1
}


# *** this should not be needed, the extra service config should not hurt the class and will enable extra demo's for the classes ***
getConfigOptions(){
### ### ###
### Need to examine these as the basis for a "y/n" menu driven deployment script...

CDDEVICE=`mount | grep "$MPOINT" | head -n 1 | cut -d " " -f 1`
VERIFYCHECKSUM=1
APPLYUPDATES=1
INSTALLRPMS=1
	# 2015-04-27  VMware Tools isn't _really_ needed, and I'm running into some
	# problems with it making scripts hang.  For now, skipping it.
INSTALLVMTOOLS=0
DONORMALCONFIG=1
DOLDAPCONFIG=1
DOKERBEROSCONFIG=1
SKIPOSCHECK=0
# Number of workstations to prepare for.  This MUST NOT BE LESS THAN 11 and
# has not been tested higher than 50.
NUMOFWS=11
for i in "$@"; do
  case $i in
	--help|-h)
	  echo ""
	  echo "In general, run this script with no arguments on a freshly-installed"
	  echo "CentOS v7.2 VM to set up a Lab Server that can deploy Lab Workstations."
	  echo ""
	  echo "The command arguments listed below are for use only by ADVANCED users"
	  echo "and those who enjoy messing things up for no good reason.  If you use"
	  echo "one of these and things break, it is YOUR fault and you should just"
	  echo "rebuild the VM from scratch."
	  echo ""
	  echo "  --nochecksum		 Do not stop if MD5 checksum fails"
	  echo "  --noupdate		 Do not attempt to apply updated RPMs via 'yum'"
	  echo "  --noinstall		 Do not install any RPMs via 'yum'"
	  echo "  --novmtools		 Do not attempt to install VMware Tools"
	  echo "  --noconfig		 Do not run the configuration steps in 'phase3.sh'"
	  echo "  --noldapconfig	 Do not run the LDAP configuration steps in 'phase3.sh'"
	  echo "  --nokerberosconfig Do not run the Kerberos configuration steps in 'phase3.sh'"
	  # Looks wrong but lines up on the screen
	  echo "  --forcerh		 Do not check distribution or version of Linux"
	  echo ""
	  exit 0
	  ;;
    --nochecksum)
	  VERIFYCHECKSUM=0
	  ;;
    --noupdate)
	  APPLYUPDATES=0
	  ;;
	--noinstall)
	  INSTALLRPMS=0
	  ;;
	--novmtools)
	  INSTALLVMTOOLS=0
	  ;;
	--noconfig)
	  DONORMALCONFIG=0
	  DOLDAPCONFIG=0
	  DOKERBEROSCONFIG=0
	  ;;
	  ############
	  # The LDAP and Kerberos flags are intended for script development, so we
	  # can more easily determine what commands are truly needed.
	--noldapconfig)
	  # At this time, the LDAP certificate creation is not skipped by this.
	  DOLDAPCONFIG=0
	  ;;
	--nokerberosconfig)
	  DOKERBEROSCONFIG=0
	  ;;
	  ############
	--forcerh)
	  SKIPOSCHECK=1
	  ;;
	*)
	  # Unrecognized
	  ;;
  esac
done
}
### ### ### 

### ** this needs to be updated to support newer versions of centos **
detectCentOS(){
DETECTEDOS=99

# 10=CentOS v7.0
# 11=CentOS v7.1
# 12=CentOS v7.2
# 99=Unknown
# Note that we will ONLY set the value to something other than '99'
# if we are *OK* with that version being used.
grep -q "^CentOS Linux release 7.0.1406 (Core)" /etc/redhat-release && DETECTEDOS=10
grep -q "^CentOS Linux release 7.1.1503 (Core)" /etc/redhat-release && DETECTEDOS=11
grep -q "^CentOS Linux release 7.2.1511 (Core)" /etc/redhat-release && DETECTEDOS=12
[ ! -f /etc/redhat-release ] && DETECTEDOS=99
if [ 2 -eq ${DETECTEDOS} ] || [ 12 -eq ${DETECTEDOS} ] ; then
  # We got CentOS v7.2
  true
else
  echo "ERROR: This is intended to be run only on CentOS 7.2.  It should"
  echo "       not be used on any other distribution or version."
  if [ 1 -eq ${SKIPOSCHECK} ]; then
    echo "DANGER: Proceeding anyway due to command argument.  This is dumb.  If this"
	echo "        spoils the milk in your fridge or kills your pet, it's YOUR FAULT."
	sleep 5
  else
    exit 1
  fi
fi
}

# *** we should not need this due to not needing an ISO for classroom environments ***
verifyMD5SUMS(){
pushd ${MPOINT} &>/dev/null
[ ! -f MD5SUMs ] && echo "ERROR: MD5SUMs file is missing!"
if ! md5sum -c MD5SUMs --quiet 2>/dev/null ; then
  echo "ERROR: One or more files failed MD5 checksum comparison.  Please verify the"
  echo "       ISO and re-download if it is corrupt.  If the file is not corrupt,"
  echo "       this is probably a development problem."
  if [ 0 -eq ${VERIFYCHECKSUM} ]; then
    echo "DANGER: Proceeding anyway due to command argument.  This is dumb.  If this"
	echo "        spoils the milk in your fridge or kills your pet, it's YOUR FAULT."
	sleep 5
  else
    exit 1
  fi
fi
popd &>/dev/null
}

##################################################################
### Get DNS Forwarder Info from DHCP
### This may get easier w/ newer NetworkManager versions
##################################################################

# Daniel_Johnson1@dell.com

# Pick out DNS and NTP settings from our DHCP lease so we can
# use the most optimal values instead of trying to guess.

getExternalDHCPInfo(){
# Interface we care about, based on knowing our connection name from Phase1
INTERFACE=`nmcli -t -f DEVICE,CONNECTION device | grep ":External$" | cut -f 1 -d ":"`

# What's the most recent lease file?
CURLEASE=`ls -1tr /var/lib/NetworkManager/dhclient*-${INTERFACE}.lease | tail -n 1`

[ ! -f "${CURLEASE}" ] && echo "No DHCP lease file for interface ${INTERFACE}, aborting!" && logger "scrape_dhcp_settings: No DHCP lease file" && exit 1
}

getDNSServerInfo(){
DNS1=`grep "option domain-name-servers" "${CURLEASE}" | tail -n 1 | cut -d " " -f 5 | cut -d ";" -f 1 | cut -d "," -f 1`
DNS2=`grep "option domain-name-servers" "${CURLEASE}" | tail -n 1 | cut -d " " -f 5 | cut -d ";" -f 1 | cut -d "," -f 2`
DNS3=`grep "option domain-name-servers" "${CURLEASE}" | tail -n 1 | cut -d " " -f 5 | cut -d ";" -f 1 | cut -d "," -f 3`

# The sed bit removes quotation marks and commas from the string
DNSSEARCH=`grep "option domain-search" "${CURLEASE}" | tail -n 1 | cut -d " " -f 5- | cut -d ";" -f 1 | sed 's/"//g;s/,//g'`
# If only one value was given, we end up with duplicates.
[ "${DNS3}" == "${DNS2}" ] && DNS3=""
[ "${DNS2}" == "${DNS1}" ] && DNS2=""
}

getNTPServerInfo(){
NTP1=`grep "option ntp-servers" "${CURLEASE}" | tail -n 1 | cut -d " " -f 5 | cut -d ";" -f 1 | cut -d "," -f 1`
NTP2=`grep "option ntp-servers" "${CURLEASE}" | tail -n 1 | cut -d " " -f 5 | cut -d ";" -f 1 | cut -d "," -f 2`
NTP3=`grep "option ntp-servers" "${CURLEASE}" | tail -n 1 | cut -d " " -f 5 | cut -d ";" -f 1 | cut -d "," -f 3`
# If only one value was given, we end up with duplicates.
[ "${NTP3}" == "${NTP2}" ] && NTP3=""
[ "${NTP2}" == "${NTP1}" ] && NTP2=""
}
##############################################################################


configureForwarder(){
rm /etc/named.forwarders.new &>/dev/null
echo "# Referenced from /etc/named.conf .  These are the external DNS servers" >> /etc/named.forwarders.new
echo "# we query when we don't have the answer.  They are set by scrape_dhcp_settings.sh ." >> /etc/named.forwarders.new
echo "forwarders {" >> /etc/named.forwarders.new
VALIDDNS=0
[ ! -z "${DNS1}" ] && echo "  ${DNS1};" >> /etc/named.forwarders.new && let VALIDDNS++
[ ! -z "${DNS2}" ] && echo "  ${DNS2};" >> /etc/named.forwarders.new && let VALIDDNS++
[ ! -z "${DNS3}" ] && echo "  ${DNS3};" >> /etc/named.forwarders.new && let VALIDDNS++
echo "};" >> /etc/named.forwarders.new
echo "" >> /etc/named.forwarders.new
# If this is the same config we had, pretend we didn't get any values
diff /etc/named.forwarders.new /etc/named.forwarders &>/dev/null && VALIDDNS=0
# Only overwrite the last file if we have something useful
[ ${VALIDDNS} -gt 0 ] && chattr -i /etc/named.forwarders && mv /etc/named.forwarders.new /etc/named.forwarders && systemctl restart named.service
rm /etc/named.forwarders.new &>/dev/null
}

##############################################################################

configureResolver(){
rm /etc/resolv.conf.new &>/dev/null
VALIDRESOLV=1
echo "# Set by a script and file marked immutable to prevent changes by anything else" >> /etc/resolv.conf.new
# Always put our local zone first, of course.  With a trailing space!
echo -n "search example.com. " >> /etc/resolv.conf.new
# By default only the first SIX search domains are used.  They must be space-separated.
if [ -z "${DNSSEARCH}" ]; then
  # DHCP didn't provide any DNS search information, using a default set.
  #echo "eerclab.dell.com. okc.amer.dell.com. amer.dell.com. us.dell.com." >> /etc/resolv.conf.new
  # On the other hand, no point in guessing right now.  Let's just terminate
  # that hanging 'echo -n'.
  echo " " >> /etc/resolv.conf.new
else
  # DHCP provided a list of DNS zones we should search when given an unqualified name
  echo "${DNSSEARCH}" >> /etc/resolv.conf.new
fi
if [ "$1" == "phase1_temp" ]; then
  echo "# TEMPORARILY using the DHCP-provided DNS servers directly." >> /etc/resolv.conf.new
  echo "# Once our own DNS daemon is running this will be changed." >> /etc/resolv.conf.new
  if [ "$VALIDDNS" -gt 0 ]; then
    [ ! -z "${DNS1}" ] && echo "nameserver ${DNS1}" >> /etc/resolv.conf.new
    [ ! -z "${DNS2}" ] && echo "nameserver ${DNS2}" >> /etc/resolv.conf.new
    [ ! -z "${DNS3}" ] && echo "nameserver ${DNS3}" >> /etc/resolv.conf.new
  else
    echo "# Or not...  We didn't GET any valid DNS servers from DHCP!" >> /etc/resolv.conf.new
    echo "nameserver 127.0.0.1" >> /etc/resolv.conf.new
  fi
else
  echo "# Since we host our own DNS zone, we cannot use external resolvers" >> /etc/resolv.conf.new
  echo "# here.  They are configured as Forwarders in /etc/named.forwarders ." >> /etc/resolv.conf.new
  echo "nameserver 127.0.0.1" >> /etc/resolv.conf.new
fi
# If this is the same config we had, pretend we didn't get any values
diff /etc/resolv.conf.new /etc/resolv.conf &>/dev/null && VALIDRESOLV=0
# Only overwrite the last file if we have something useful
[ ${VALIDRESOLV} -gt 0 ] && chattr -i /etc/resolv.conf && mv /etc/resolv.conf.new /etc/resolv.conf && chattr +i /etc/resolv.conf
rm /etc/resolv.conf.new &>/dev/null
}


##############################################################################
##############################################################################

configureChrony(){
rm /etc/chrony.conf.new &>/dev/null
cp /etc/chrony.conf.base /etc/chrony.conf.new &>/dev/null
VALIDNTP=0
[ ! -z "${NTP1}" ] && echo "server ${NTP1} iburst" >> /etc/chrony.conf.new && let VALIDNTP++
[ ! -z "${NTP2}" ] && echo "server ${NTP2} iburst" >> /etc/chrony.conf.new && let VALIDNTP++
[ ! -z "${NTP3}" ] && echo "server ${NTP3} iburst" >> /etc/chrony.conf.new && let VALIDNTP++
# If this is the same config we had, pretend we didn't get any values
diff /etc/chrony.conf.new /etc/chrony.conf &>/dev/null && VALIDNTP=0
# Only overwrite the last file if we have something useful
[ ${VALIDNTP} -gt 0 ] && chattr -i /etc/chrony.conf && mv /etc/chrony.conf.new /etc/chrony.conf && chattr +i /etc/chrony.conf && systemctl restart chronyd.service
rm /etc/chrony.conf.new &>/dev/null
}

logResults(){
logger "scrape_dhcp_settings: DNS values ${DNS1} ${DNS2} ${DNS3}; NTP values ${NTP1} ${NTP2} ${NTP3}; DNSSEARCH ${DNSSEARCH}"
}




##################################################################
##################################################################

### Need to understand this part better...
doWeirdStuff1(){
[ -d ${FTPDIR}/ ] || mkdir -p ${FTPDIR}/

`echo "bG9nZ2VyIFRoaXMgd2FzIGEgdHJpdW1waC4K" | base64 -d`
echo "Passed sanity checks, copying small files and setting up links."

# PostInstall Temp Dir
PITD=`mktemp -d`
LOG="${PITD}/phase1.log"
( echo "${BL1}"; echo "${BL2}"; echo "${BL3}"; echo "${BL4}" ) >>"${LOG}"
echo "${KICKSTARTRELEASE}" > /etc/kickstart-release

cp -af ${MPOINT}/ftppub/* ${FTPDIR}/
cp -f ${MPOINT}/breakme /usr/local/sbin/
cp -f ${MPOINT}/.scrape_dhcp_settings.sh /usr/local/sbin/scrape_dhcp_settings.sh
chmod 555 /usr/local/sbin/breakme
chmod 555 /usr/local/sbin/scrape_dhcp_settings.sh

# Rather than renaming those files, let's just make symlinks.  This
# helps preserve their version information in plain sight.  The sorting
# from "ls" is sufficient until we go from (for instance) single to double
# digits, so "sort -V" is used to keep things sane.
pushd ${FTPDIR} &>/dev/null
rm -f VMwareTools.tar.gz station_ks.cfg &>/dev/null
ln -s $(ls VMwareTools-*.tar.gz | sort -V | tail -n 1) VMwareTools.tar.gz | tee -a "${LOG}"
ln -s $(ls station_ks_*.cfg | sort -V | tail -n 1) station_ks.cfg | tee -a "${LOG}"
popd &>/dev/null

restorecon -R ${FTPDIR}
}


############################################################
# General network setup
############################################################

getNICInfo(){
nmcli -t -f DEVICE,TYPE,CONNECTION,CON-UUID device | grep "ethernet" > ${PITD}/NICs
NUM_OF_NICS=`wc -l < ${PITD}/NICs`
# Ensure value is numeric
let NUM_OF_NICS+=0
if [ 2 -gt ${NUM_OF_NICS} ]; then
  echo "ERROR: There are not enough Ethernet NICs available.  Ensure you have 2 and" | tee -a "${LOG}"
  echo "       try again." | tee -a "${LOG}"
  exit 1
fi
if [ 2 -lt ${NUM_OF_NICS} ]; then
  echo "I only need two Ethernet NICs, but you have ${NUM_OF_NICS}.  That's OK," | tee -a "${LOG}"
  echo "I'll just use the first two.  You can do what you want with the rest." | tee -a "${LOG}"
fi
}

getNICOrder(){
# So what's the magical way we decide which NIC is #1 vs #2?
# We just take whatever order is output from 'nmcli'.  Yes, lame.
NIC1NAME=`head -n 1 < ${PITD}/NICs | cut -d ":" -f 1`
NIC1CON=`head -n 1 < ${PITD}/NICs | cut -d ":" -f 3`
NIC1CONUUID=`head -n 1 < ${PITD}/NICs | cut -d ":" -f 4`
NIC2NAME=`head -n 2 < ${PITD}/NICs | tail -n 1 | cut -d ":" -f 1`
NIC2CON=`head -n 2 < ${PITD}/NICs | tail -n 1 | cut -d ":" -f 3`
NIC2CONUUID=`head -n 2 < ${PITD}/NICs | tail -n 1 | cut -d ":" -f 4`
}


doWeirdNICVoodoo(){
### This seems arbitrarily convoluted to me, perhaps due to 
### the original design's reliance on VMWare, so this might
### be simplified...

# I find it interesting that the network setup steps don't take a
# predictable amount of time to run.  It seems to vary considerably.

# Only clear/re-create the settings for NIC1 if it does NOT have a
# connection called "External"
if [ "${NIC1CON}" != "External" ]; then
  echo "nmcli device disconnect ${NIC1NAME}" &>>"${LOG}"
  nmcli device disconnect ${NIC1NAME} &>>"${LOG}"
  if [ "${NIC1CONUUID}" != "--" ]; then
    # If the connection name/UUID is '--' then it was blank/not set.
	echo "nmcli connection delete uuid ${NIC1CONUUID}" &>>"${LOG}"
    nmcli connection delete uuid ${NIC1CONUUID} &>>"${LOG}"
  fi
  # "DHCP" is implied when you don't specify an IP address.  In fact I see no way
  # to explicitly state DHCP as an option...?
  echo "nmcli connection delete id ${NIC1NAME}" &>>"${LOG}"
  nmcli connection delete id ${NIC1NAME} &>>"${LOG}"
  echo "nmcli connection add type ethernet con-name External ifname ${NIC1NAME}" &>>"${LOG}"
  nmcli connection add type ethernet con-name External ifname ${NIC1NAME} &>>"${LOG}"
  echo "nmcli connection modify External connection.zone \"external\" ipv4.ignore-auto-dns \"true\" ipv4.dns \"127.0.0.1\" ipv4.dns-search \"example.com\"" &>>"${LOG}"
  nmcli connection modify External connection.zone "external" ipv4.ignore-auto-dns "true" ipv4.dns "127.0.0.1" ipv4.dns-search "example.com" &>>"${LOG}"
  # To ensure that our just-modified settings for DNS are used, briefly re-drop the connection
  echo "nmcli device disconnect ${NIC1NAME}" &>>"${LOG}"
  nmcli device disconnect ${NIC1NAME} &>>"${LOG}"
  sleep 2
  echo "nmcli device connect ${NIC1NAME}" &>>"${LOG}"
  nmcli device connect ${NIC1NAME} &>>"${LOG}"
  # And give it time to find an address.
  sleep 2
  echo "NIC1 (${NIC1NAME}) configured for DHCP operation.  Current address (if any):" | tee -a "${LOG}"
else
  echo "The first NIC (${NIC1NAME}) looks like it was already configured.  To" | tee -a "${LOG}"
  echo "avoid changing anything that you've customized, I'll leave it alone." | tee -a "${LOG}"
  echo "Current address (if any):" | tee -a "${LOG}"
fi
ip address show ${NIC1NAME} | grep "inet" | cut -d " " -f 1-6 | tee -a "${LOG}"

# IPv4 - Internal is 172.26.0.0/24
# IPv6 - Internal is FD07:DE11:2015:0324::/64
#        Anything in the FD::/8 (actually FC::/7) is OK.
#        I just made this up with today's date.

# Always clear/re-create the settings for NIC2
echo "nmcli device disconnect ${NIC2NAME}" &>>"${LOG}"
nmcli device disconnect ${NIC2NAME} &>>"${LOG}"
if [ "${NIC2CONUUID}" != "--" ]; then
  # If the connection name/UUID is '--' then it was blank/not set.
  echo "nmcli connection delete uuid ${NIC2CONUUID}" &>>"${LOG}"
  nmcli connection delete uuid ${NIC2CONUUID} &>>"${LOG}"
fi
echo "nmcli connection delete id ${NIC2NAME}" &>>"${LOG}"
nmcli connection delete id ${NIC2NAME} &>>"${LOG}"
echo "nmcli connection delete id Internal" &>>"${LOG}"
nmcli connection delete id Internal &>>"${LOG}"
echo "nmcli connection add type ethernet con-name Internal ifname ${NIC2NAME} ip4 172.26.0.1/24 ip6 fd07:de11:2015:0324::1/64" &>>"${LOG}"
nmcli connection add type ethernet con-name Internal ifname ${NIC2NAME} ip4 172.26.0.1/24 ip6 fd07:de11:2015:0324::1/64 &>>"${LOG}"
# Repeating the DNS information so that NetworkManager will be certain to use
# the proper values even if the External connection is down for some reason.
echo "nmcli connection modify Internal connection.zone \"internal\" ipv4.dns \"127.0.0.1\" ipv4.dns-search \"example.com\"" &>>"${LOG}"
nmcli connection modify Internal connection.zone "internal" ipv4.dns "127.0.0.1" ipv4.dns-search "example.com" &>>"${LOG}"
# For much the same reasons as above, we're going to briefly drop this connection also.
echo "nmcli device disconnect ${NIC2NAME}" &>>"${LOG}"
nmcli device disconnect ${NIC2NAME} &>>"${LOG}"
sleep 2
echo "nmcli device connect ${NIC2NAME}" &>>"${LOG}"
nmcli device connect ${NIC2NAME} &>>"${LOG}"
sleep 2
echo "NIC2 (${NIC2NAME}) configured with static addresses"  | tee -a "${LOG}"
#echo "              172.26.0.1 and fd07:de11:2015:0324::1." | tee -a "${LOG}"
# Oh let's go ahead and read it live, eh?
ip address show ${NIC2NAME} | grep "inet" | cut -d " " -f 1-6 | tee -a "${LOG}"
echo ""  | tee -a "${LOG}"
# And a full dump for the debug log
ip address show  &>>"${PITD}/ip_a_s.txt"
nmcli connection &>>"${PITD}/nmcli_con.txt"
nmcli device &>>"${PITD}/nmcli_dev.txt"
ethtool ${NIC1NAME} &>>"${PITD}/ethtool_1.txt"
ethtool ${NIC2NAME} &>>"${PITD}/ethtool_2.txt"

# Use our DHCP-assigned DNS and NTP settings in a way more appropriate than
# what NetworkManager would normally do.  We'll be doing a better job after
# our local DNS server is running, so for now use a special flag.
/usr/local/sbin/scrape_dhcp_settings.sh phase1_temp &>/dev/null
}

doHostnameStuff(){
############################################################
# Hostname.  Note that the shell prompt won't be updated
# until reboot or logoff/on.
# Make a backup of the hosts file, *OR* revert to that backup.
[ ! -f /etc/hosts_orig ] && cp -a /etc/hosts /etc/hosts_orig || cp -a /etc/hosts_orig /etc/hosts
# Despite having DNS setup later, we need this for LDAP/Kerberos.
echo "172.26.0.1  server1.example.com  server1" >> /etc/hosts
echo "server1.example.com" > /etc/hostname
hostname server1
}

doCentralTime(){
# Timezone (defaults to Eastern/New York)
( cd /etc && rm localtime && ln -s ../usr/share/zoneinfo/US/Central )
}

############################################################

# *** need to remove all calls to phase2 and phase3 scripts *** 
doWeirdStuff2(){
# That's all we can do without extra packages.  Now we need to transfer
# control out of the mount-point, unmount the PostInstall ISO, and
# prompt the user to connect the full CentOS 7.2 ISO

cp ${MPOINT}/.phase2.sh ${PITD}/phase2.sh
cp ${MPOINT}/.phase3.sh ${PITD}/phase3.sh
mkdir ${PITD}/iso_tail
# Hmm, could just copy the file for the detected OS.
cp ${MPOINT}/iso_tail/* ${PITD}/iso_tail/
[ -f ${MPOINT}/rhel7_updates.tgz ] && cp ${MPOINT}/rhel7_updates.tgz ${PITD}

chmod +x ${PITD}/phase2.sh
chmod +x ${PITD}/phase3.sh

cat <<EOF>${PITD}/phase1.vars
# PITD		PostInstall Temp Dir
PITD="${PITD}"
# FTPDIR	The 'pub' subdirectory on the FTP server
FTPDIR="${FTPDIR}"
# MPOINT	Where the PostInstall ISO is/was mounted
MPOINT="${MPOINT}"
# CDDEVICE	What device we found the PostInstall ISO in
CDDEVICE="${CDDEVICE}"
# NIC1NAME  Name of the first configured Ethernet NIC
NIC1NAME="${NIC1NAME}"
# NIC2NAME  Name of the second configured Ethernet NIC
NIC2NAME="${NIC2NAME}"
# VERIFYCHECKSUM  Validate checksum of files from PostInstall ISO
VERIFYCHECKSUM="${VERIFYCHECKSUM}"
# INSTALLRPMS   Run normal RPM installation
INSTALLRPMS="${INSTALLRPMS}"
# APPLYUPDATES  Allow yum to apply updated packages
APPLYUPDATES="${APPLYUPDATES}"
# INSTALLVMTOOLS  Try to install VMware Tools
INSTALLVMTOOLS="${INSTALLVMTOOLS}"
# DONORMALCONFIG   Run phase3.sh's configuration steps
DONORMALCONFIG="${DONORMALCONFIG}"
# DOLDAPCONFIG   Run phase3.sh's configuration steps for LDAP
DOLDAPCONFIG="${DOLDAPCONFIG}"
# DOKERBEROSCONFIG   Run phase3.sh's configuration steps for Kerberos
DOKERBEROSCONFIG="${DOKERBEROSCONFIG}"
# SKIPOSCHECK   Don't fail for unsupported OS
SKIPOSCHECK="${SKIPOSCHECK}"
# DETECTEDOS   What OS did we find?
DETECTEDOS="${DETECTEDOS}"
# NUMOFWS   Number of workstations to prepare for (11<=x<=50)
NUMOFWS="${NUMOFWS}"
EOF

# Just in case
set &>>"${PITD}/phase1_debug_set"

# Back to root's home directory.
cd 
}

startPhase2(){
# How we call phase2 depends on how we were originally called.
# Since we were executed from the ISO mount point, the hand-off
# to phase2.sh must be done in this careful way to allow bash
# to release its lock on the device, otherwise we won't be able
# to unmount and eject it.
if am_I_sourced ; then
  ${PITD}/phase2.sh ${PITD}/phase1.vars
else
  exec ${PITD}/phase2.sh ${PITD}/phase1.vars
fi
}

##########################################################################
### Initial setup complete
### Service configuration prep
##########################################################################

sanityCheck1(){
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
LOG="${PITD}/phase2.log"

umount -l ${MPOINT} &>>"${LOG}"
umount -f ${MPOINT} &>>"${LOG}"
eject ${CDDEVICE} &>>"${LOG}"
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to unmount/eject the CD/DVD device.  Aborting." | tee -a "${LOG}"
  exit 1
fi
echo "Phase one complete.  The PostInstall ISO has been unmounted." | tee -a "${LOG}"
echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-" | tee -a "${LOG}"
}

# *** as we are not using an ISO locally, this should not be needed *** 
sanityCheck2(){
# Manual sanity check for you, Mr. Maintainer:
# If ISOSIZE is not a multiple of 2048 then something is wrong,
# and the script may mis-compute some things when attempting
# error recovery.

# With just the basic CentOS 7.0 ISO available we should see 4,405 packages.
# Including the HighAvailability and ResilientStorage repos brings 4,439.
# I'm happy to have at least 4,405.

# Always define at least one URL, even if it's not going to be reachable.
# If a particular DNS name has a *single* static IP, consider adding the
# url in IP-format under "ISOURLalt[x]".  This way if a DNS lookup fails
# we can try again by IP.

case ${DETECTEDOS} in
  10) # CentOS v7.0
    SHORTHUMANNAME="CentOS v7.0"
    # Here 'DVD' is meant to differentiate between the ISO we want and the 8GB 'Everything' ISO
    LONGHUMANNAME="CentOS Linux v7.0 DVD"
    ISO=CentOS-7.0-1406-x86_64-DVD.iso
    # Official public primary source
    ISOURL[0]="http://vault.centos.org/7.0.1406/isos/x86_64/CentOS-7.0-1406-x86_64-DVD.iso"
    ISOURLalt[0]="http://108.61.16.227/7.0.1406/isos/x86_64/CentOS-7.0-1406-x86_64-DVD.iso"
	ISOURL[1]="http://archive.kernel.org/centos-vault/7.0.1406/isos/x86_64/CentOS-7.0-1406-x86_64-DVD.iso"
    # OKC EERC.  Run by Daniel_Johnson1.
    ISOURL[2]="http://dyson.okc.eerclab.dell.com/fs/Lab/OSISO/Linux/CentOS/7.0/CentOS-7.0-1406-x86_64-DVD.iso"
    ISOURLalt[2]="http://10.14.176.76/fs/Lab/OSISO/Linux/CentOS/7.0/CentOS-7.0-1406-x86_64-DVD.iso"
    # RR EERC.  Run by Keith_Wier.
    ISOURL[3]="http://file1.eerc.local/SoftLib/ISOs/Linux/CentOS/7.0/CentOS-7.0-1406-x86_64-DVD.iso"
    ISOURLalt[3]="http://10.180.48.120/SoftLib/ISOs/Linux/CentOS/7.0/CentOS-7.0-1406-x86_64-DVD.iso"
    ISOSIZE=4148166656
    ISOSHA256=ee505335bcd4943ffc7e6e6e55e5aaa8da09710b6ceecda82a5619342f1d24d9
    ISO_HEAD_20MB_MD5=a49b6b79181160f7ab1fc2da2c5e5e96
    # Mount point relative to the FTP root, used in some URLs
    ISOMOUNTDIRREL="centos-7.0/dvd"
    ISOMOUNTDIR="${FTPDIR}/${ISOMOUNTDIRREL}"
    ISOMOUNTVERIFY="CentOS_BuildTag"
    ISOTAIL=centos70
    ISOMINPKGS=3538
    YUMDISTRO_NAME="CentOS-7.0 x86_64"
    # Caution, the 'short name' is used for path elements.  NO SPACES!
    YUMSHORT_NAME="centos-7.0_x64"
    YUMGPGPATH="file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7"
    ;;
  12) # CentOS v7.2
    SHORTHUMANNAME="CentOS v7.2"
    # Here 'DVD' is meant to differentiate between the ISO we want and the 8GB 'Everything' ISO
    LONGHUMANNAME="CentOS Linux v7.2 DVD"
    ISO=CentOS-7.2-1406-x86_64-DVD.iso
    # Official public primary source
    ISOURL[0]="http://vault.centos.org/7.2.1511/isos/x86_64/CentOS-7.2-1511-x86_64-DVD.iso"
    ISOURLalt[0]="http://108.61.16.227/7.2.1511/isos/x86_64/CentOS-7.2-1511-x86_64-DVD.iso"
	ISOURL[1]="http://archive.kernel.org/centos-vault/7.2.1511/isos/x86_64/CentOS-7.2-1511-x86_64-DVD.iso"
    # OKC EERC.  Run by Daniel_Johnson1.
    ISOURL[2]="http://dyson.okc.eerclab.dell.com/fs/Lab/OSISO/Linux/CentOS/7.2/CentOS-7.2-1511-x86_64-DVD.iso"
    ISOURLalt[2]="http://10.14.176.76/fs/Lab/OSISO/Linux/CentOS/7.2/CentOS-7.2-1511-x86_64-DVD.iso"
    # RR EERC.  Run by Keith_Wier.
    ISOURL[3]="http://file1.eerc.local/SoftLib/ISOs/Linux/CentOS/7.2/CentOS-7.2-1511-x86_64-DVD.iso"
    ISOURLalt[3]="http://10.180.48.120/SoftLib/ISOs/Linux/CentOS/7.2/CentOS-7.2-1511-x86_64-DVD.iso"
	# Other public sources
	ISOURL[4]="http://isoredirect.centos.org/centos/7/isos/x86_64/CentOS-7-x86_64-DVD-1511.iso"
	ISOURL[5]="http://mirror.vtti.vt.edu/centos/7.2.1511/isos/x86_64/CentOS-7-x86_64-DVD-1511.iso"
    ISOSIZE=4329570304
    ISOSHA256=907e5755f824c5848b9c8efbb484f3cd945e93faa024bad6ba875226f9683b16
    ISO_HEAD_20MB_MD5=da700b7b197c1e3a382263c5680a4776
    # Mount point relative to the FTP root, used in some URLs
    ISOMOUNTDIRREL="centos-7.2/dvd"
    ISOMOUNTDIR="${FTPDIR}/${ISOMOUNTDIRREL}"
    ISOMOUNTVERIFY="CentOS_BuildTag"
    ISOTAIL=centos72
    ISOMINPKGS=1
    YUMDISTRO_NAME="CentOS-7.2 x86_64"
    # Caution, the 'short name' is used for path elements.  NO SPACES!
    YUMSHORT_NAME="centos-7.2_x64"
    YUMGPGPATH="file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7"
    ;;
 99) # Unknown / unsupported
    ;&  # This makes us fall through to the next match, whether good or not.
  *)
    echo "I have no idea what media to use since you aren't using a supported OS."
    echo "You are on your own here, buddy."
    sleep 10m
    exit 1
    ;;
esac

# *** we shouldn't need this as we have combined all of this into a new single script *** 
### Lumping this into sanityCheck2() because it's not worth its own function
# Update list of environment variables
cat  >>${PITD}/phase1.vars <<EOF
#################
# Added in phase2
LONGHUMANNAME="${LONGHUMANNAME}"
# Relative to the FTP path
ISOMOUNTDIRREL="${ISOMOUNTDIRREL}"
ISOMOUNTDIR="${ISOMOUNTDIR}"
# distro_name and short_name are used in yum repository files
YUMDISTRO_NAME="${YUMDISTRO_NAME}"
YUMSHORT_NAME="${YUMSHORT_NAME}"
YUMGPGPATH="${YUMGPGPATH}"
EOF
}

################


# *** another section we should  not need due to not needing a local ISO ***
optimizeISODownload(){
# Perform quick reachability test on URLs.  We'll examine results later.
URLMAX=${#ISOURL[@]}
ISODOWNLOAD=0
mkdir "${PITD}/URLSPEED/"
{
  # The "-m 2" sets the overall operation timeout in seconds.  This run is basically
  # just priming DNS and any proxy server we're using.  Sadly a DNS timeout is going
  # to take 15 seconds no matter what we set here, so need to run the per-URL checks
  # backgrounded (and in parallel) to avoid an unacceptable delay.
  for (( N=0; N < ${URLMAX}; N++ )); do
    {
      curl ${ISOURL[${N}]} -o /dev/null -ks -m 2 -w '%{speed_download},%{http_code}' > "${PITD}/URLSPEED/${N}"
      # If the response from that was all-zeroes (in other words, unreachable) and
      # if there is a defined alternate for this URL, try that.  Since we can't make
      # variable changes in our parent process we drop the alternate URL in a text file
      # to act as a flag.
      grep -q ",000" "${PITD}/URLSPEED/${N}" && [ ! -z "${ISOURLalt[${N}]}" ] && touch "${PITD}/URLSPEED/${N}.alturl" && curl ${ISOURLalt[${N}]} -o /dev/null -ks -m 2 -w '%{speed_download},%{http_code}' > "${PITD}/URLSPEED/${N}"
    } &
  done
  wait # Let those processes run to completion before we continue...
} & # ...but wrap all of /those/ in yet another background process that we'll wait for later.
URLCHECKPID=$!
}


# *** again, local ISO, let's trim this out ***
doISOTailStuff(){
# Now I plan to have the cached tail-end of the ISO be exactly
# 100MB (104,857,600 bytes) every time, but honestly I should be careful
# and have the script read the file's size.  This also lets me easily
# notice if the tail is *missing* and then skip the code sections that
# attempt to use it.
ISO_TAIL_SIZE=0
[ -f ${PITD}/iso_tail/${ISOTAIL} ] && ISO_TAIL_SIZE=`du -b ${PITD}/iso_tail/${ISOTAIL} | cut -f 1`
# How to grab the last 100MB of a disc/ISO:   Set ISOSIZE and CDDEVICE first
# dd if=${CDDEVICE} bs=2048 count=51200 skip=$(( ( ${ISOSIZE} - 104857600 ) / 2048 )) of=/tmp/last_100mb_of_disc
###

[ $(( ${ISOSIZE} % 2048 )) -ne 0 ] && echo "CAUTION: The script-specified size for the install ISO is not a multiple of 2048" | tee -a "${LOG}" && echo "         bytes.  This is likely a mistake!  Pausing for 10 minutes." | tee -a "${LOG}" && sleep 10m
}

### These are used by all these ISO related functions... Made my brain hurt...
# True must be zero for shell conditionals to work.  I set these to make the code read better.
# "return 1" may confuse someone, "return $FALSE" is clear.
TRUE=0
FALSE=1


ISOCheckSHA256 () {
  # Simple read-only check, does the file/device argument I was given have the right SHA256 checksum?
  sha256sum -b ${1} | grep -q "${ISOSHA256} *" && return $TRUE
  return $FALSE
}

ISOCheckHead () {
  # Arg1 is the full path to an ISO/device we'll be checking.
  # Compute MD5 of the first 20MB (2KB sectors for optical media) and compare
  # to our known-good value.  Avoiding use of units in the command since I
  # don't trust them to be consistent (1,000 vs 1,024).
  dd if=${1} bs=2048 count=10240 2>/dev/null | md5sum -b | grep -q "${ISO_HEAD_20MB_MD5}" && return $TRUE
  return $FALSE
}

ISOTailFix () {
  # Arg1 is the full path to an ISO we'll be checking/correcting/hashing.
  # We return $TRUE if the file is fully correct at the end, False otherwise.
  [ ! -f ${1} ] && echo "ERROR: ISOTailFix() was given a non-regular-file argument:" | tee -a "${LOG}" && echo "       ${1}" | tee -a "${LOG}" && return $FALSE
  if [ ! -w ${1} ]; then
    # Before we reject this, does it happen to be correct?
    ISOCheckSHA256 ${1} && return $TRUE
    echo "WARNING: ISOTailFix() was given a non-writable argument with the wrong checksum:" | tee -a "${LOG}"
	echo "         ${1}" | tee -a "${LOG}"
	return $FALSE
  fi
  local ____ISOSIZEONDISK=`du -b ${1} | cut -f 1`
  # We can't fix something if we have no Tail file
  if [ ${ISO_TAIL_SIZE} -gt 0 ]; then
    # If what we got is within 100MB of the proper size, we can try to fix it.
    if [ ${____ISOSIZEONDISK} -gt $(( ${ISOSIZE} - ${ISO_TAIL_SIZE} - 1 )) ]; then
      # 100MB == 104,857,600 == 51,200 blocks of 2,048 bytes
	  # What we are going to do is take our 100MB pre-saved ISO 'tail' and use
	  # it to overwrite/append the end of the ISO we just read.
	  dd if=${PITD}/iso_tail/${ISOTAIL} bs=1 count=${ISO_TAIL_SIZE} seek=$(( ${ISOSIZE} - ${ISO_TAIL_SIZE} )) of=${1} &>>"${LOG}"
	  # And let's chop off any excess (the 'dd' above will not do this for us)
	  truncate -s ${ISOSIZE} ${1}
    fi
  fi
  ISOCheckSHA256 ${1} && return $TRUE
  return $FALSE
}

# *** local ISO, should not need this either ***
sanityCheck3(){
# Let us not tamper with the ISO until we are sure it is not mounted
umount ${ISOMOUNTDIR} &>>"${LOG}"
umount ${FTPDIR}/${ISO} &>>"${LOG}"
echo "${ISOSHA256} *${ISO}" > ${FTPDIR}/${ISO}.sha256
# Remove any lines which reference the ISO in /etc/fstab
sed --in-place "/${ISO}/d" /etc/fstab &>/dev/null
HAVEMEDIA=no
}

# *** need to rework this, no local ISO file ***
doWeirdISOStuff1(){
# Set up a list of ISOs that we want to consider, in order of preference.
# We will end up using the first one that is (or can be made) correct.
# Do note that this is DESTRUCTIVE testing: If a file is not correct we will
# try to modify it, and ultimately it will be deleted if it fails testing.
# Always check the final desired path first, even if it does not exist.
echo -n "Checking for valid ${SHORTHUMANNAME} ISO in the filesystem..." | tee -a "${LOG}"
echo "${FTPDIR}/${ISO}" > ${PITD}/isos_to_check
find / -type f -iname "*.iso" -size ${ISOSIZE}c -print 2>/dev/null | grep -v -f ${PITD}/isos_to_check > ${PITD}/isos_to_check.rightsize 
cat ${PITD}/isos_to_check.rightsize >> ${PITD}/isos_to_check
# This gets everything that is not more than $ISO_TAIL_SIZE (100mb) too small.
# Note this includes files that are larger than the ISO is supposed to be.
find / -type f -iname "*.iso" -size +$(( ${ISOSIZE} - ${ISO_TAIL_SIZE} ))c -print 2>/dev/null | grep -v -f ${PITD}/isos_to_check > ${PITD}/isos_to_check.wrongsize 
cat ${PITD}/isos_to_check.wrongsize >> ${PITD}/isos_to_check

# "Wait, what are you reading?"  File is specified at the END of the loop.
# This avoids interesting gotchas in how bash handles environment variables.
# http://fog.ccsf.edu/~gboyd/cs160b/online/7-loops2/whileread.html
while read CANDIDATE; do
  echo ""
  echo -n "."
  # The file does still exist, right?  Hey it never hurts to check.
  [ -f ${CANDIDATE} ] || continue
  # If the file's head is incorrect just skip it and move on.
  # This should protect any incorrect ISOs that happen to be approximately the size we want.
  echo -n ".."
  ISOCheckHead ${CANDIDATE} || continue
  HAVEMEDIA=no
  # Is it correct?
  echo -n "..."
  ISOCheckSHA256 ${CANDIDATE} && HAVEMEDIA=yes
  # Is it fixable?
  [ "no" == "${HAVEMEDIA}" ] && echo -n "...." && ISOTailFix ${CANDIDATE} && HAVEMEDIA=yes
  # If no, free up disk space
  [ "no" == "${HAVEMEDIA}" ] && rm -f ${CANDIDATE} && echo -n "  :("
  # If the file is correct, put it in the final location
  [ "yes" == "${HAVEMEDIA}" ] && [ "${CANDIDATE}" != "${FTPDIR}/${ISO}" ] && mv ${CANDIDATE} ${FTPDIR}/${ISO}
  [ "yes" == "${HAVEMEDIA}" ] && echo "" && break
done < ${PITD}/isos_to_check

# Check results of earlier URL reachability test.
# First of all, ensure those tests are done (max time 15 seconds)
wait ${URLCHECKPID}
# Anything that returns non-zero is reachable
for (( N=0; N < ${URLMAX}; N++ )); do
  # If the test report does not start with "0.0", it was reachable.
  # That's all we care about right now.
  grep -q "^0.0" "${PITD}/URLSPEED/${N}" || ISODOWNLOAD=1
  # Was this using an alternate URL?  If so, switch out the primary URL variable.
  [ -f "${PITD}/URLSPEED/${N}.alturl" ] && ISOURL[${N}]="${ISOURLalt[${N}]}"
done

HAVEMEDIA=no
[ -f ${FTPDIR}/${ISO} ] && HAVEMEDIA=yes

if [ "no" == "${HAVEMEDIA}" ]; then
  echo ""
  echo "Failed to find a valid ISO already on this system." | tee -a "${LOG}"
  echo ""
  if [ ${ISODOWNLOAD} -eq 0 ]; then
    echo "Unable to reach any of the download URLs for the ISO." | tee -a "${LOG}"
  fi
  # Must be prepared for string-comparison here
  while [ "${ISODOWNLOAD}" == "1" ]; do
    echo "At least one URL for the ISO appears to be reachable.  Would you like me to" | tee -a "${LOG}"
    echo "acquire the file from a network source?   If you say No here then you will have" | tee -a "${LOG}"
	echo "to provide a disc/ISO locally.  Please enter only Y or N." | tee -a "${LOG}"
    read -n 1 ISODOWNLOAD
    case ${ISODOWNLOAD} in
      Y)
        ;&
      y)
        ISODOWNLOAD=y
        echo "User answered Y." >> "${LOG}"
        ;;
      N)
        ;&
      n)
        ISODOWNLOAD=0
        echo "User answered N." >> "${LOG}"
        ;;
      *)
        ISODOWNLOAD=1  # Reset the loop
        echo "Invalid selection."  | tee -a "${LOG}"
        echo
    esac
  done
fi
}

# *** again, no local ISO file *** 
doWeirdISOStuff2(){
# At this point ISODOWNLOAD is one of three values.
# 0  No URLs were reachable or user declined download
# 1  At least one URL was reachable but it was not needed, we have an ISO already
# y  We need an ISO, at least one URL was reachable, and user wants us to try it

if [ "${ISODOWNLOAD}" == "y" ]; then
  echo | tee -a "${LOG}"
  echo "Determining fastest mirror..." | tee -a "${LOG}"
  URLFASTEST=0
  for (( N=0; N < ${URLMAX}; N++ )); do
    # If the prior result was zero then we couldn't reach it, and won't try now.
    grep -q ",000"  ${PITD}/URLSPEED/${N} || curl ${ISOURL[${N}]} -o /dev/null -ks -m 5 -w "%{speed_download},${N},%{http_code}\n" >> "${PITD}/URLSPEED/realtest"
  done
  sort -rn "${PITD}/URLSPEED/realtest" > "${PITD}/URLSPEED/sorted"
  # Now the file has the fastest responses first
  SPEEDCOUNT=0
  while read SPEEDLINE; do
    URLSBYSPEED[${SPEEDCOUNT}]=`echo "${SPEEDLINE}" | cut -d "," -f 2`
    let SPEEDCOUNT++
  done < "${PITD}/URLSPEED/sorted"

  echo "Starting with ${URLSBYSPEED[0]}, ${ISOURL[${URLSBYSPEED[0]}]}" >> "${LOG}"
  URLUSING=0
  echo "Number of elements in URLSBYSPEED = ${#URLSBYSPEED[@]}" >> "${LOG}"
  for (( N=0; N<${#URLSBYSPEED[@]}; N++ )); do
    echo "URLSBYSPEED[${N}]=${URLSBYSPEED[${N}]}" >> "${LOG}"
  done
  while [ ${URLUSING} -lt ${#URLSBYSPEED[@]} ] && [ "no" == "${HAVEMEDIA}" ]; do
    echo "`date`  URLUSING=${URLUSING}   URLSBYSPEED[${URLUSING}]=${URLSBYSPEED[${URLUSING}]}   ISOURL[${URLSBYSPEED[${URLUSING}]}]=${ISOURL[${URLSBYSPEED[${URLUSING}]}]}" >> "${LOG}"
    echo "Downloading from `echo "${ISOURL[${URLSBYSPEED[${URLUSING}]}]}" | cut -d "/" -f 3`" | tee -a "${LOG}"
    curl ${ISOURL[${URLSBYSPEED[${URLUSING}]}]} -o ${FTPDIR}/${ISO} -k | tee -a "${LOG}"
    echo
    echo "Verifying checksum and (if needed) tweaking..." | tee -a "${LOG}"
    ISOTailFix ${FTPDIR}/${ISO} && HAVEMEDIA=yes
    if [ "no" == "${HAVEMEDIA}" ]; then
      echo -n "File is corrupt or invalid.  "
      let URLUSING++
      if [ ${URLUSING} -lt ${#URLSBYSPEED[@]} ]; then
        # We have more URLs to try
        echo "Trying next-fastest source."
        echo
        echo
      else
        # Out of URLs, give up
        echo "Out of URLs to try."
        echo
      fi
    fi
  done
fi
}


# *** not needed for classroom environment, more ISO stuff ***
doHaveMediaStuff(){
if [ "no" == "${HAVEMEDIA}" ]; then
  echo ""
  echo "Insert/connect/attach the ${LONGHUMANNAME} disc/ISO now."
  echo "I will only be checking the first optical device on the system.  You don't"
  echo "need to press any keys."
else
  echo "Found a valid ISO, so there is no need for you to provide an ISO/disc." | tee -a "${LOG}"
  echo | tee -a "${LOG}"
fi

while [ "no" == "$HAVEMEDIA" ]; do
  sleep 2
  mount ${CDDEVICE} ${MPOINT} &>/dev/null || continue
  # That was really just a way to see if we had a valid disc present.
  umount ${MPOINT} &>/dev/null
  ISOCheckHead ${CDDEVICE} && HAVEMEDIA=maybe
  [ "no" == "${HAVEMEDIA}" ] && echo "A disc was detected but it is the wrong one.  Try again please."  | tee -a "${LOG}" && eject ${CDDEVICE} &>/dev/null && sleep 5
done

if  [ "maybe" == "${HAVEMEDIA}" ]; then
  echo "Contents appear to be correct, copying to local storage." | tee -a "${LOG}"
  # 'cp' should work fine, but I'm not positive that it matches the block size
  # automatically.  Using 'dd' A) ensures we copy as efficiently as possible
  # and B) sets an upper limit on how much we copy if the disk/ISO is corrupt.
  dd if=${CDDEVICE} bs=2048 count=$(( ${ISOSIZE} / 2048 )) of=${FTPDIR}/${ISO} &>>"${LOG}"
  eject ${CDDEVICE} &>>"${LOG}"
  echo "Verifying checksum and (if needed) tweaking..." | tee -a "${LOG}"
  ISOTailFix ${FTPDIR}/${ISO} && HAVEMEDIA=yes
fi

# *** again, more ISO stuff, not needed *** 
# Remove the tail file from local disk, so we can (later) make a well-compressed log bundle
rm ${PITD}/iso_tail/ -rf &>/dev/null

if [ "yes" == "${HAVEMEDIA}" ]; then
  echo "Copy complete." | tee -a "${LOG}"
else
  echo "WARNING: The ISO failed to copy properly and completely, or is corrupt on the" | tee -a "${LOG}"
  echo "         source disc.  The (apparently corrupt) file is being deleted." | tee -a "${LOG}"
  rm -f ${FTPDIR}/${ISO} &>/dev/null
  echo "ERROR: Without the installation ISO we can't load the needed packages to continue."
  echo "       You will need to start the post-install from scratch."
  exit 1
fi
}

# *** more ISO Stuff ***
mountISOStuff(){
# Set fstab to mount it on boot.
echo "${FTPDIR}/${ISO}  ${ISOMOUNTDIR}  auto  ro,loop,context=system_u:object_r:public_content_t:s0  1 0" >> /etc/fstab
rm -rf ${ISOMOUNTDIR} &>/dev/null
mkdir -p ${ISOMOUNTDIR} &>/dev/null
restorecon -R ${ISOMOUNTDIR} ${FTPDIR}/${ISO}*
mount ${ISOMOUNTDIR}  | tee -a "${LOG}"

if [ ! -f "${ISOMOUNTDIR}/${ISOMOUNTVERIFY}" ]; then
  echo "ERROR: The ISO did not mount properly or something else has gone very wrong." | tee -a "${LOG}"
  echo "       Aborting."  | tee -a "${LOG}"
  mount &>>"${LOG}"
  exit 1
fi
}

# These values used to be set just by some grep, cut, and sed work.  Red Hat no longer
# has such a verbose name in the file, and I don't see the point in trying to
# automate this to handle later versions.
##export repo_file=`find ${ISOMOUNTDIR} -type f -name "media.repo"|head -n1`
##export distro_name=`grep name= $repo_file | cut -d= -f2`
##export short_name=`echo $distro_name|sed -e 's/Red Hat Enterprise Linux /rhel/'`
#distro_name="RHEL-7.0 Server.x86_64"
#short_name="rhel-7.0_x64"
# We need these later, in phase3

# *** will not need custom repo's for classroom environment *** 
doRepoStuff1(){
case ${DETECTEDOS} in
  10) # CentOS v7.0
    # Unlike RHEL, CentOS has default repository files.  We don't want them
    # because 1) we want to control the packages directly and 2) they cause
    # errors if they are unreachable.
    for REPO in Base CR Debuginfo fasttrack Media Sources Vault; do
     mv /etc/yum.repos.d/CentOS-${REPO}.repo /root &>/dev/null
    done
    ;;
  12) # CentOS v7.2
    # Unlike RHEL, CentOS has default repository files.  We don't want them
    # because 1) we want to control the packages directly and 2) they cause
    # errors if they are unreachable.
    for REPO in Base CR Debuginfo fasttrack Media Sources Vault; do
      mv /etc/yum.repos.d/CentOS-${REPO}.repo /root &>/dev/null
    done
    ;;
  99) # Unknown / unsupported
    ;&  # This makes us fall through to the next match, whether good or not.
  *)
  ;;
esac

if [ ! -f /etc/yum.repos.d/${YUMSHORT_NAME}.repo ]; then
  cat >/etc/yum.repos.d/${YUMSHORT_NAME}.repo <<EOF
[InstallMedia]
name=${YUMDISTRO_NAME}
baseurl=file://${ISOMOUNTDIR}
gpgcheck=0
cost=0

EOF
  if [ ${DETECTEDOS} -lt 10 ]; then
    # RHEL system, append the HA/Resilient repos
  cat >>/etc/yum.repos.d/${YUMSHORT_NAME}.repo <<EOF
[dvd-HighAvailability]
name=DVD for ${YUMSHORT_NAME} - HighAvailability
baseurl=file://${ISOMOUNTDIR}/addons/HighAvailability
enabled=1
gpgcheck=0

[dvd-ResilientStorage]
name=DVD for ${YUMSHORT_NAME} - ResilientStorage
baseurl=file://${ISOMOUNTDIR}/addons/ResilientStorage
enabled=1
gpgcheck=0
EOF
  fi
fi

# Basically just checking to see if 'yum' is running without complaint.
# Any syntax errors in /etc/yum.repos.d will make the commands fail.
yum clean all &>>"${LOG}"
if ! yum list &>"${PITD}/yum_list.txt" ; then
  echo "ERROR: The 'yum' command did run properly.  Have one of the instructors" | tee -a "${LOG}"
  echo "       or mentors examine your environment for clues." | tee -a "${LOG}"
  exit 1
fi

# With just the basic CentOS 7.0 ISO available we should see 4,405 packages.
# Including the HighAvailability and ResilientStorage repos brings 4,439.
# I'm happy to have at least 4,405.
# These are now being set when we decide which ISO we'll use, because the
# counts ARE different.
if [ `cat ${PITD}/yum_list.txt | wc -l` -lt ${ISOMINPKGS} ]; then
  echo "ERROR: Something seems to be wrong, we aren't seeing enough packages" | tee -a "${LOG}"
  echo "       when querying 'yum'.  Have one of the instructors or mentors" | tee -a "${LOG}"
  echo "       examine your environment for clues." | tee -a "${LOG}"
  exit 1
fi

echo "DVD mounted and package repositories working, setting up packages now." | tee -a "${LOG}"
# First ensure we update whatever is already installed...
if [ ${APPLYUPDATES} -eq 1 ]; then
  echo "Applying pre-install updates." &>> "${LOG}"
  yum -y update &>"${PITD}/yum_update.txt"
else
  echo "Pre-install updates skipped by argument." | tee -a "${LOG}"
  sleep 2
fi
}


############################################################
# Package Installation
############################################################

doPackageInstall(){

# And now install what we really need.
if [ ${INSTALLRPMS} -eq 1 ]; then
  echo "Package installation in progress..." | tee -a "${LOG}"
  yum -y install "@Console Internet Tools" "@System Management" "@System Administration Tools" pax dmidecode oddjob sgpio \
    certmonger pam_krb5 krb5-server krb5-workstation perl-DBD-SQLite httpd vsftpd nfs-utils nfs4-acl-tools dhcp tftp tftp-server \
    bind-chroot bind-utils  createrepo openldap openldap-servers openldap-devel openldap-clients ypserv migrationtools \
    selinux-policy-targeted policycoreutils-python syslinux iscsi-initiator-utils ftp lftp samba-client samba* unzip zip lsof \
    mlocate targetd targetcli tcpdump pykickstart links chrony net-tools patch rng-tools open-vm-tools screen rsync \
    policycoreutils-devel sos xinetd vim bash-completion &>"${PITD}/yum_install.txt"
  echo >>"${PITD}/yum_install.txt"
  yum -y install ${FTPDIR}/materials/sl-*.rpm &>>"${PITD}/yum_install.txt"
  # scsi-target-utils not in the normal RHEL7 repo, it is deprecated.  You can still get it from EPEL though.
  # It was replaced by LIO, aka targetd & targetcli.
  #
  # net-tools is obsolete and deprecated, but contains "ifconfig" and is needed
  # for either open-vm-tools or VMware Tools to work properly.  According to
  # https://bugzilla.redhat.com/show_bug.cgi?id=1151644 this should be fixed
  # (for open-vm-tools) in the next release.
  echo "...complete." | tee -a "${LOG}"
else
  echo "Package installation skipped by argument.  " | tee -a "${LOG}"
  sleep 5
fi
echo ""
}

doVMToolsStuff(){
############################################################
# Open-VM-Tools
############################################################
# It is installed above but the service doesn't load until
# reboot...normally.
systemctl status vmtoolsd.service &>> "${LOG}"
systemctl start vmtoolsd.service &>> "${LOG}"

############################################################
# VMware Tools
############################################################
# This used to be one of the first things done, but it requires
# perl which isn't available on RHEL 7 until after we get our
# list of packages installed.
#     ###################
#     # Does it matter? #    http://kb.vmware.com/kb/2073803
#     ###################
# See that KB article, but basically on modern Linux we should
# expect "open-vm-tools" to take care of us without installing
# the 'legacy' VMware Tools.  The VMware Tools installer is
# aware of this and, by default, aborts gracefully rather than
# get in the way.
#
# I am leaving this code block in place and I plan to keep
# updating the PostInstall-bundled VMware Tools just in case.
if dmidecode | grep -q "Product Name: VMware Virtual Platform"; then
  if [ ${INSTALLVMTOOLS} -eq 1 ]; then
    echo "Decompressing VMware Tools installer package." | tee -a "${LOG}"
    pushd /tmp &>/dev/null
    [ -d vmware-tools-distrib ] && rm vmware-tools-distrib -rf &>/dev/null
    tar -xzf ${FTPDIR}/VMwareTools.tar.gz
    if [ $? -eq 0 ]; then
      # Decompressed without errors, good
      cd vmware-tools-distrib
      # Set this variable later if VMware Tools are already installed, else leave it junky
      VMTVER="bogusbogusbogusNOTinstalled"
      which vmware-toolbox-cmd &>/dev/null && VMTVER=`vmware-toolbox-cmd -v | cut -d " " -f 1`
      if grep -iRq "${VMTVER}" * &>/dev/null ; then
        echo "VMware Tools already installed and version matches, leaving as-is." | tee -a "${LOG}"
      else
        # Default to 'newer', we will install the Packaged VMware Tools.
        PVMTIS=newer
        # What is the Packaged VMware Tools Version?  Hope they don't change this variable  name.
        PVMTVER=`grep "\\$buildNr =" vmware-install.pl | cut -d "'" -f 2 | cut -d " " -f 1`
	    # Split these up to Major, Minor, and Revision numbers...
	    PVMTVERMAJ=`echo "${PVMTVER}" | cut -d "." -f 1`
	    PVMTVERMIN=`echo "${PVMTVER}" | cut -d "." -f 2`
	    PVMTVERREV=`echo "${PVMTVER}" | cut -d "." -f 3`
	    VMTVERMAJ=`echo "${VMTVER}" | cut -d "." -f 1`
	    VMTVERMIN=`echo "${VMTVER}" | cut -d "." -f 2`
	    VMTVERREV=`echo "${VMTVER}" | cut -d "." -f 3`
	    # ...adding zero ensures we have a numeric result even with an alpha input...
	    let PVMTVERMAJ+=0
	    let PVMTVERMIN+=0
	    let PVMTVERREV+=0
	    let VMTVERMAJ+=0
	    let VMTVERMIN+=0
	    let VMTVERREV+=0
	    # ...and now compare them.
	    [ ${PVMTVERMAJ} -lt ${VMTVERMAJ} ] && PVMTIS=older
	    [ ${PVMTVERMIN} -lt ${VMTVERMIN} ] && PVMTIS=older
	    [ ${PVMTVERREV} -lt ${VMTVERREV} ] && PVMTIS=older
	    # Sanity check, in case the Package Version seems to be flat-out wrong, just install it.
	    # This probably indicates that they changed something and our version check is getting trash.
	    [ 9 -gt ${PVMTVERMAJ} ] && PVMTIS=newer
	    echo "VMTVER=${VMTVER}" >>"${LOG}"
	    echo "PVMTVER=${PVMTVER}" >>"${LOG}"
	    echo "PVMTIS=${PVMTIS}" >>"${LOG}"
	    if [ "older" == "$PVMTIS" ]; then
  	    echo "The installed VMware Tools is newer than the package(s) I have access to," | tee -a "${LOG}"
	      echo "so skipping installation." | tee -a "${LOG}"
	    else
          echo "Installing VMware Tools." | tee -a "${LOG}"
          ./vmware-install.pl --default &>>"${LOG}"
          # Just in case some background process needs to let go first...
          sleep 2
	    fi
	  fi # Version did not match installed
    else
      echo "CAUTION: VMware Tools was needed but failed to decompress properly." | tee -a "${LOG}"
    fi # Checking that the Tools decompressed OK
    rm vmware-tools-distrib -rf &>/dev/null
    popd &>/dev/null
  else
    echo "Skipping VMware Tools due to command argument." | tee -a "${LOG}"
  fi
else
  echo "VMware Tools is not needed on this system, skipping." | tee -a "${LOG}"
fi
}

############################################################

doDebugHalt(){
[ -f /DEBUG_HALT1 ] && echo "Halting as ordered, DEBUG_HALT1"  | tee -a "${LOG}" && exit 0
}

startPhase3(){
exec ${PITD}/phase3.sh ${PITD}/phase1.vars
}

##########################################################################
### Service prep complete 
### Begin advanced service configuration
##########################################################################

# *** not needed, we do this up above *** 
sanityCheck4(){
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
}

######################
#if [ ${DONORMALCONFIG} -eq 1 ]; then   
# Not indenting all of this, search for "DONORMALCONFIG" to find the end of the if block
#echo "Setting up general stuff." | tee -a "${LOG}"

setKSRelease(){
############################################################
# /etc/kickstart-release
############################################################
# Set in the first file, postinstall.sh
#echo "CentOS Lab server1 kickstart 1.0.0" >/etc/kickstart-release
cat /etc/kickstart-release >>/etc/issue
}


startRNGD(){
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
}


doLabRouteTesting(){
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
}


startWebServer(){
############################################################
# web server httpd
############################################################
echo "   httpd / Apache" | tee -a "${LOG}"
cd /var/www/html
ln -s ${FTPDIR}
systemctl enable httpd.service &>>"${LOG}"
systemctl start httpd.service &>>"${LOG}"
}

startFTPServer(){
############################################################
# ftp server vsftpd
############################################################
echo "   vsftpd" | tee -a "${LOG}"
systemctl enable vsftpd.service &>>"${LOG}"
systemctl start vsftpd.service &>>"${LOG}"
}

configureDHCPServer(){
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
}

configureDNSServer(){
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
}

configurePXEServer(){
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
}

configureNTPServer(){
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
}


############################################################
# NIS server - Deprecated, commented out 2015-07-01
############################################################


configureLabUsers(){
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
}

configureCerts(){
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

}

configureLDAPServer(){
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
}

configureKRB5(){
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
}


configureNFSServer(){
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
}

configureSMBServer(){
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
}

configureISCSIServer(){
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
}

createLocalUsers(){
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
}


############################################################
# final steps
############################################################
echo "   Miscellaneous" | tee -a "${LOG}"

updateManDB(){
# Ensure the manpage database is current, especially after adding the _selinux pages.
mandb &>>"${LOG}"
}

doFinalRPMStuff(){
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

}

doSSHStuff(){
mkdir -m 700 -p /root/.ssh
ssh-keygen -q -t rsa -N '' -f /root/.ssh/id_rsa &>>"${LOG}"
cp /root/.ssh/id_rsa.pub "${FTPDIR}/materials/" &>>"${LOG}"
echo "UseDNS no" >>/etc/ssh/sshd_config
# less readable, but left as a note. & replaces the matched text
# sed -e 's/GSSAPIAuthentication yes/#&/' -i /etc/ssh/sshd_config
sed -e 's/#GSSAPIAuthentication no/GSSAPIAuthentication no/' -e 's/GSSAPIAuthentication yes/#GSSAPIAuthentication yes/' -i /etc/ssh/sshd_config
}

doFinalWeirdStuff1(){
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
}

evasiveAction(){

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
}

configureFirewallStuff(){
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
}

#else # DONORMALCONFIG     if block
#  echo "Not applying normal configuration." | tee -a "${LOG}"
#fi # End of DONORMALCONFIG main if block

###################


grabMiscGoodies(){
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
}

magicalEasterEggs(){
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
}

doASCIIArt(){
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
}

scrapeDNSForwarder(){
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
}


# Make sure this database is current
/etc/cron.daily/mlocate &>>"${LOG}"

logALittleNote(){
`echo "bG9nZ2VyIElcJ20gbWFraW5nIGEgbm90ZSBoZXJlOiBIVUdFIFNVQ0NFU1MK" | base64 -d`
}

getSupportBundle(){
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
}

attaBoy(){
`echo "bG9nZ2VyIEl0XCdzIGhhcmQgdG8gb3ZlcnN0YXRlIG15IHNhdGlzZmFjdGlvbi4K" | base64 -d`
}

finalReboot(){
echo ""
echo ""
echo "All done."
echo ""
echo ""
echo "Now we are going to reboot the server!"
echo ""
sleep 10
reboot
}
