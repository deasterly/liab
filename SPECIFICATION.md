# Server Requirements
- Minimal install of CentOS7.x
- Use kickstart to:
	- Install git, bash-completion, and vim (any more?)
	- Download setup scripts and other files w/ KS postinstall script
- Kickstart post-install starts the script(s) downloaded from github
- Required services:
	- NFS
	- SMTP
	- SMB
	- DHCPD
	- DNS
	- TFTP / PXE
	- NTP
	- HTTPD
	- RSYSLOGD
	- LDAP
	- FIREWALLD
	- VSFTPD
	- NFS-SECURE
	- iSCSI
- Required hardware:
	- OS H/W Minumum and 20GB+ free space
	- 2 NICs (LAN + Internet)

# Workstation Requirements
- VM or PC that can PXE boot from SERVER LAN NIC
	- Configuration handled by kickstart

- Required hardware:
	- OS H/W Minimum
	- 20+GB Boot HDD + 3 or more additional data HDDs
	- 1+ NIC


