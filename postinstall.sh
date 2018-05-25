#!/bin/bash

# Banner lines
BL1="Linux In A Box lab server, PostInstall configuration   [====/"
BL2="2017-05-02 for CentOS 7.2 x64                          // "
BL3="                                                           //  "
BL4="                                                          //   "
KICKSTARTRELEASE="Linux server1 kickstart v1.1.12"

echo ""
echo "${BL1}"; echo "${BL2}"; echo "${BL3}"; echo "${BL4}"

# Daniel_Johnson1@dell.com      Aaron_Southerland@dell.com
# This script was made to automate the initial setup of the Red Hat In
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

# Absolute path to the 'pub' directory for the FTP server
FTPDIR=/var/ftp/pub

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

# Lazyness - If we are being sourced, I need to remove all the 'exit's and substitute
# something that won't log you out.  But I'd rather not spend time on that right now, so...
if am_I_sourced ; then
  echo "ERROR: This script must be called directly rather than being 'sourced'."
  # See, can't use 'exit' here
  return 0
fi

[ 0 -ne $UID ] && echo "ERROR: This MUST be run as root!  Try again." && exit 1
if am_I_sourced ; then
  MPOINT=`dirname ${BASH_SOURCE[0]}`
else
  MPOINT=`dirname $0`
fi
[ "/" != "${MPOINT:0:1}" ] && echo "ERROR: You must call this script using an absolute path, not a relative path." && echo "       Example:  /mnt/postinstall.sh" && exit 1
# I'm not sure that this would be a problem I can't bypass but why take chances?
pwd | grep -q "^${MPOINT}" && echo "ERROR: You must NOT call this script from the mount point directory itself." && echo "       Use something like    cd /root; ${0}" && exit 1
# "What on earth is this?"  We had an issue when someone specified iso9660 as the mounting filesystem type.
# It messed with the length and case-sensitivity of filenames.  If this long nasty name survives, the others will too.
[ ! -f ${MPOINT}/.fsflag.Aa-Bb-Cc_Dd_Ee_Ff.1.2.3.4.5.6.7.9.10.11.12.13.14.15.16.17.18.19.20.21.22.23.24.25.txt ] && echo "ERROR: ISO mounted with the WRONG filesystem, names are corrupt." && echo "       Re-mount without specifying a filesystem type." && exit 1
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

############################################################
# General network setup
############################################################
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

# So what's the magical way we decide which NIC is #1 vs #2?
# We just take whatever order is output from 'nmcli'.  Yes, lame.
NIC1NAME=`head -n 1 < ${PITD}/NICs | cut -d ":" -f 1`
NIC1CON=`head -n 1 < ${PITD}/NICs | cut -d ":" -f 3`
NIC1CONUUID=`head -n 1 < ${PITD}/NICs | cut -d ":" -f 4`
NIC2NAME=`head -n 2 < ${PITD}/NICs | tail -n 1 | cut -d ":" -f 1`
NIC2CON=`head -n 2 < ${PITD}/NICs | tail -n 1 | cut -d ":" -f 3`
NIC2CONUUID=`head -n 2 < ${PITD}/NICs | tail -n 1 | cut -d ":" -f 4`

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

############################################################
# Hostname.  Note that the shell prompt won't be updated
# until reboot or logoff/on.
# Make a backup of the hosts file, *OR* revert to that backup.
[ ! -f /etc/hosts_orig ] && cp -a /etc/hosts /etc/hosts_orig || cp -a /etc/hosts_orig /etc/hosts
# Despite having DNS setup later, we need this for LDAP/Kerberos.
echo "172.26.0.1  server1.example.com  server1" >> /etc/hosts
echo "server1.example.com" > /etc/hostname
hostname server1

############################################################
# Timezone (defaults to Eastern/New York)
( cd /etc && rm localtime && ln -s ../usr/share/zoneinfo/US/Central )

############################################################


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
