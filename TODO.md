5/24/2018 (Initial rough draft)



disable dhcp service on instructor jump box
deploy Liab Server1 onto station10
centos 7.x minimal install
root password should be P@ssw0rd!
do not create an additional user account
configure em2 with static ip of 192.168.1.00/24 with a route 192.168.1.1
copy cent iso from IJB to server1 :/root/cento.iso using scp
mount Liab.iso via idrac to /mnt on server1
/mnt/postinstall.sh
server will reboot, when server is back up, yum update -y
then reboot
after server reboots, you should be good to pxe boot the rest of the servers
 
 
need to setup post install script to setup ifcfg-External with 192.168.1.100/24 with a gateway 192.168.1.1
 
in postinstall script -> leave default repo files in original location
need to add 10.206.0.143 to named.forwarders on server1 in postinstall script
 
need to update to a more recent version of centos

Need to create git branches for each major project to support from this code base
Possible branches: Linux on BME, Linux in a Box universal learning lab, Intro to Linux on Dell PowerEdge, Linux CLI Skills, et.al..

