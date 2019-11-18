FSNAME=lustrarm
FSTYPE=ldiskfs
NETTYPE=tcp
DEBUG_SIZE=1024
MOUNT=/lustre
MOUNT2=/mnt/lustre
DIR2=/mnt/lustre
DIR=/lustre
RUNAS_ID=500
RUNAS_GID=500
RUNAS='sudo -u runas'
# MDS and MDT configuration
MDSCOUNT=1

mds_HOST="MDSMGS"
mds_host="MDSMGS"
mgs_HOST="MDSMGS"
mgs_host="MDSMGS"
MGSNID="MDSMGS"
mdt_HOST="MDSMGS"
mdt_host="MDSMGS"
MDSDEV1="/dev/vdb1"
MGSDEV="/dev/vdb1"
MGSDEV1="/dev/vdb1"

# OSS and OST configuration
OSTCOUNT=1

ost_HOST="OST"
OSTDEV1="/dev/vdb1"
OSTDEV="/dev/vdb1"
OST1DEV="/dev/vdb1"
OSSDEV="/dev/vdb1"
OSSDEV1="/dev/vdb1"

# Client configuration
CLIENTCOUNT=1
CLIENTS="client"
RCLIENTS="client"

PDSH="/usr/bin/pdsh -l root -S -Rssh -w"

MODOPTS_LIBCFS="libcfs_panic_on_lbug=0"
FAIL_ON_ERROR=${FAIL_ON_ERROR:-true}
PTLDEBUG=-1
SUBSYSTEM="all"
DAEMONFILE="/tmp/lustre-debug.log"
