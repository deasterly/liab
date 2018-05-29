#!/bin/bash

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

sanityCheck3(){
# Let us not tamper with the ISO until we are sure it is not mounted
umount ${ISOMOUNTDIR} &>>"${LOG}"
umount ${FTPDIR}/${ISO} &>>"${LOG}"
echo "${ISOSHA256} *${ISO}" > ${FTPDIR}/${ISO}.sha256
# Remove any lines which reference the ISO in /etc/fstab
sed --in-place "/${ISO}/d" /etc/fstab &>/dev/null
HAVEMEDIA=no
}


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
