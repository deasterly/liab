     Dell Training
    Red Hat In A Box
  Lab Server setup disc

This disc takes a stock "Minimal" RHEL/CentOS v7.2 installation (on a VM) and
turns it into a server for a Red Hat training lab.  Properly created
workstation VMs will be installed via PXE boot and then be suitable for
self-paced practice using instructions from Dell Global Learning and
Development.

It is primarily expected to be used in VMware Workstation v11 but we will also
support it in VMware Workstation 10, vSphere v5.5, and vSphere v6.0.  It will
probably work just fine in other hypervisors but we A) are not going to test
them and B) will not investigate problems they cause.

While the environment should work with CentOS as well RHEL, we do not
currently support a mixed environment.  The distribution you use on the server
is what will be used for the workstations.

Expected server configuration:
  One CPU core
  768MB RAM
  20GB thin-provisioned hard disk
  NIC1: External NAT, bridge, or host-only
  NIC2: Internal VM-to-VM

Expected workstation configuration: (each)
  One CPU core
  1GB RAM
  20GB thin-provisioned hard disk
  Four 1GB thin-provisioned hard disks
  NIC1: Internal VM-to-VM

OVA template files are provided in this ISO for quickly creating mostly-correct
VMs but *you* are responsible for ensuring that the proper virtual networks are
selected for the virtual NICs!  DO NOT BLAME US if you stick a DHCP server on
a production network.

The script will need access to the full installation DVD/ISO for the detected
running distribution and will prompt you for that at the appropriate time.
If your network configuration allows, it will offer to download the file from
a network/Internet source.  If that requires an HTTP Proxy on your network you
can set that at the command line with a line like one of these examples:
  export http_proxy="http://address:port"
  export http_proxy="http://user:password@address:port"
You may also upload/copy such an ISO to your server VM before running this
script.  The name is unimportant so long as it ends with ".iso".

