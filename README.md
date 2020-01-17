# HPC-SIG Lustre CI recipes

## General Overview

This repository contains recipes to build and test Lustre on AArch64 platforms.
It also contains a script and kickstart file(s) to provision an environment (a VM) with the necessary requirements to **build**, **install** and **test** Lustre from its git repository.
Currently, the supported platform for **building**, **installing** and **testing** is **CentOS8**.
There are also *old* scripts to build on **RHEL8** and **build the client only** on **CentOS 7 altarch**.

But it is **highly** recommended to use CentOS8.

Please also note that since Lustre Server's **LDISKFS** requires modifications to the *ext4 kernel driver sources*, it is tied to the kernel version.
As of the writing of this README, **on CentOS8 AArch64, the latest kernel supported is 4.18.0-80.11.2 (that is the latest 8.0 release)**.

## Requirements

The script to install the VMs : *centos8vm/create_centos8_qemuvirt.sh* installs its own software dependencies to install the VM (that would be libvirt, qemu-kvm, virt-install and related dependencies).
One thing it **omits is the installation of Mellanox OFED stack**, and the configuration of the Virtual Functions. The configuration of the Virtual Functions can be done using *helper_scripts/ib-enable-sriov.sh* (Thanks to @rafaeldtinoco).

Please note that as of the writing of this README, **SRIOV/Virtual Functions proper operation requires the M(ellanox)OFED stack to be installed on CentOS7, else the VM UEFI will get stuck on initializing the VF** (*tested on ThunderX2*).

To summarize, the only hard requirement on the machine side is to have **MOFED installed (and be sure the VFs do work)**.
Another requirement, on the infrastructure side, is to have a fileserver/webserver able to serve the resulting RPMs from Lustre building (for the install and subsequent testing), as well as the kernel sources (to build Lustre against).
The kickstart files also assume that you are using [MrProvisioner](https://github.com/mr-provisioner/mr-provisioner) as a provisioner (as well as URLs corresponding to the HPC-SIGs)
The kickstart file containing all requirements for Lustre building, installing and testing is **centos8vm/Centos8.Upstream.LustreVM.ks**

*Note: this could be substituted by a PXE/TFTP server and a web server able to jinja template the correct variables into the kickstart and serve it*

*Note2: it would require some changes to the URLs, name of the initrd/kernel images and no doubt variables in the script as well as the kickstarts*


## Operation of the recipes

### I - Installing the VMs

To install the VMs, make sure the above requirements are satisfied.
Once done, as a user that as full access to the hypervisor :
```bash
$ VMNUM="The index of the VM to be created : an integer is expected, default is 1"
$ IBVF="The index of the Virtual Function to be used by the VM : an integer is expected, default is 16-$VMNUM"
$ centos8vm/create_centos8_vm.sh
```

This operation will create the VM alongside two disks : a 45GB and a 15GB one.
The 45GB one is sda which CentOS8 will boot on.
The 15GB one, sdb, is the disk reserved for Lustre.

Please note that the LustreVM kickstart also downgrades the kernel to the latest supported version and blacklists it in yum.conf.
This requires a repository containing the full set of RPMs.

### II - Building Lustre

Requires user with sudo access (preferably passwordless):
```bash
$ ./build_lustre_centos8_latest.sh
```

The Lustre (Server **and** client) build done here builds both **LDISKFS** and **ZFS** support.
Thus it builds ZFS, which is not available in the upstream repositiories for AArch64.
Currently, the version built by the scripts is the latest : **0.8.2** (*so no SPL*)
ZFS requires access to the Kernel sources.
(*Author's note: the build probably can be streamlined since it seems to repeat some steps*)

If ZFS is already installed, it will not build it (*this can be easily toggled with a '!' placed accordingly*).

It also builds Lustre's accompanying e2fsprogs as well as packages it (*following upstream documentation*).
Note that as of the writing of this README, the version built is above CentOS8's default one, so it upgrades easily.
Also note that, as is the case with ZFS, building can be avoided with a '!' placed accordingly.
(*Author's note: e2fsprogs' configuration takes quite a while*)

Once the above are built, Lustre is built. First the client, then the server. It is built from upstream Whamcloud's git master (but if a sourcetree is already there the script will not overwrite it).
The server requires access to the **FULL** kernel sources (in CentOS7, debuginfo contained those, but CentOS8 doesn't seem to).
As a rule of thumb, always have the SRPM of the kernel lying somewhere (even though they might be hard to track down...)

Every RPM produced is put into a directory ($DIR_REPO) and createrepo is run against it.
A .repo file is added to yum and installation of ZFS and e2fsprogs is done that way.
**NOTE: Lustre is not installed at the end of the build**

### III - Installing Lustre

Requires user with sudo access (preferably passwordless):
```bash
$ ./install_lustre_centos8.sh
```

This step is the only one that requires some human intervention :
One needs to get the IP of the nodes provisioned using the kickstart to serve as testing (note that it should be displayed on the login prompt, for ease of use).
Then one needs to fill the centos8vm/cluster_template with the IPs, hostnames, and partition name of the Lustre dedicated volume.

The RPMs produced by the above process have to put on a webserver to be served to the installation environment.

The installation script is intended to be run on each node of the testing cluster before testing.
Thus, not only does it install Lustre but it also installs requirements, amends the hosts file, puts the testing configuration in the correct place.

**NOTE: One of the requirements is pdsh, which is not present in the upstream CentOS8 repos as far as I'm aware. Thankfully, building the rpms for it is straightforward**

Currently the test configuration assumes 1 MDS/MGS, 1 OSS, 1 Client (in addition to the MDS/MGS node acting as a client).
It also assumes LDISKFS as a backend.

### IV - Testing Lustre

Requires user with sudo access (preferably passwordless):
```bash
$ vim templates/cluster_template
$ ./testing_lustre_centos8.sh
```

This script is intended to be run on **ONLY** one node of the testing cluster **AT ANY ONE TIME**.
It will first bring up the Lustre cluster with llmount.sh (in the case of any errors at this stage, make sure to either run llmountcleanup.sh, or reboot all nodes).
Then it will run the sanity test suite.
*Note: it is run directly, not through auster*

## Conclusion

These recipes serve as a basis for running CI on Lustre.
There is still work to be done to fully automate the pipeline, most notably :

- [ ] Automate IP (rest can be infered by Jenkins) recuperation for templating
- [ ] Automate transfer of produced RPMs to the webserver
- [ ] Automate recuperation of test suite results, eventual kdumps and error reports to some place
- [ ] Automate booting back up of the VMs after they have been provisioned
- [ ] Ansiblelize what makes sense to be transposed to Ansible
- [ ] Add ZFS backend support for testing configuration 
- [ ] Add InfiniBand link support for testing configuration (via VM's VFs) 
- [ ] Add multiple OSS, MDS/MGS support in testing configuration
- [ ] Add support for testing at scale

Also, openSUSE support still needs to be added.

## Note to developers

I have tried to make the scripts as easily readable as possible, and did strive for adaptability (although it could be a lot better).
The goal here is to have a lean, mean and straightforward approach to build this stack. 
So I have been quite lazy and haven't done a full write up on all the variables in the scripts (since they should be quite evident, and are *only* spread around 4 files).
