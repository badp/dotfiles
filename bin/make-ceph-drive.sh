#!/bin/bash

if [ $# -ne 1 ]
then
  echo "Usage: `basename $0` {id}"
  exit 1
fi

CLUSTER_PATH="/etc/ceph/"
CLUSTER=(`find $CLUSTER_PATH -regex ".*conf" |
          sed "s#${CLUSTER_PATH}##g" |
          sed "s#.conf##g"`)
CONF_FILE=/etc/ceph/${CLUSTER}.conf
FSID=`grep fsid ${CLUSTER} | cut -f2 -d= | tr -d ' '`
ID=$1
PV=(`pvdisplay -c | cut -f1 -d: | tr -d ' '`) #split into array:
                                              #implicitly only use one value
VGROUP=(`pvdisplay -c | cut -f2 -d: | tr -d ' '`) #this should be the right one
NAME=${CLUSTER}${ID}
DISK=/dev/$VGROUP/$NAME
PARTITION=/dev/mapper/${VGROUP}-${NAME}
MOUNTPOINT=/var/lib/ceph/osd/${CLUSTER}-${ID}
FS=ext4
ALLOC_SIZE=250 #GB

PROMPT="Hit Enter to proceed, Ctrl-C to abort: "

################################################################################
# -1/5 Sanity checks!

# Configuration file not found
if [ ! -f $CONF_FILE ]
  then
    echo Error: No .conf file found under $CLUSTER_PATH
    exit 1
fi

# More than one physical volume
if [ ${#PV[@]} -ne 1 ]
  then
    PV_WARN="${#PV[@]} available"
    PROMPT="Make sure the right physical volume was guessed. $PROMPT"
  else
    PV_WARN="LGTM"
fi

# Not enough disk space
PVDISPLAY=`pvdisplay $PV -c`
EXTENT_SIZE=`echo $PVDISPLAY | cut -f8 -d:` #kB
AVAIL_EXTENTS=`echo $PVDISPLAY | cut -f10 -d:`
EXTENTS_NEEDED=`expr $ALLOC_SIZE \* 1024 \* 1024 / $EXTENT_SIZE`
if [ $EXTENTS_NEEDED -gt $AVAIL_EXTENTS ]
  then
    ALLOC_WARN="not enough disk space!"
    PROMPT="Hit Ctrl-C to abort (press Enter if you're feeling lucky):"
  else
    ALLOC_WARN="LGTM"
fi

# More than one ceph cluster
if [ ${#CLUSTER[@]} -ne 1 ]
  then
  CLUSTER_WARN="${#CLUSTER[@]} available"
  PROMPT="Make sure the right cluster was guessed. $PROMPT"
else
  CLUSTER_WARN="LGTM"
fi

# ID doesn't look good
if [[ $ID != [0-9] ]]
  then
  ID_WARN="invalid"
  PROMPT="Hit Ctrl-C to abort (press Enter if you're feeling lucky): "
else
  # ID is numeric, but not actually in ceph.conf
  if ! grep -q "osd.${ID}" /etc/ceph/ceph.conf
    then
    ID_WARN="not configured"
    PROMPT="Hit Ctrl-C to abort (press Enter if you're feeling lucky): "
  else
    # ID is configured, but not for this host
    if ! (grep -A2 "osd.${ID}" /etc/ceph/ceph.conf | grep -q `hostname -s`)
      then
      ID_WARN="possibly wrong host"
      else
        ID_WARN="LGTM"
    fi
  fi
fi

# The logical volume already exists
if (lvdisplay -c | grep -q "/${NAME}:")
  then
  NAME_WARN="already exists!"
  PROMPT="Hit Ctrl-C to abort (press Enter if you're feeling lucky): "
else
  NAME_WARN="LGTM"
fi

# Something else is already mounted there
if (mount | grep -q $MOUNTPOINT)
  then
  MOUNT_WARN="already mounted!"
  PROMPT="Hit Ctrl-C to abort (press Enter if you're feeling lucky): "
else
  MOUNT_WARN="LGTM"
fi

echo "##############################################################################"
echo "# 0/5 Configuration"
echo

column -nts~ << EOF
Variable~Meaning~Value~Notes
~
\$CLUSTER~Ceph cluster~$CLUSTER~$CLUSTER_WARN
\$CONF_FILE~Ceph conf file~$CONF_FILE~lgtm
\$ID~OSD id~$ID~$ID_WARN
\$PV~Physical volume~$PV~$PV_WARN
\$VGROUP~Volume group~$VGROUP~lgtm
\$NAME~Logical volume~$NAME~$NAME_WARN
\$ALLOC_SIZE~Allocation size~$ALLOC_SIZE GB~$ALLOC_WARN
\$DISK~LV device file~$DISK~lgtm
\$PARTITION~Partition path~$PARTITION~lgtm
\$MOUNTPOINT~Mount point~$MOUNTPOINT~$MOUNT_WARN
\$FS~Filesystem~$FS~lgtm
EOF

echo
read -p "$PROMPT" -r
echo

# Begin serious time.

set -u
set -e
set -v

##############################################################################
# 1/5 - Creating logical volume...

lvcreate $VGROUP $PV -L${ALLOC_SIZE}G -n $NAME

##############################################################################
# 2/5 Creating file system...

mkfs.$FS $PARTITION

##############################################################################
# 3/5 Mounting file system...

mkdir -p $MOUNTPOINT
mount -o user_xattr $PARTITION $MOUNTPOINT

##############################################################################
# 4/5 Initializing Ceph filesystem in place...
# (This step may fail safely if not enough of ceph is already in place)

ceph-osd -i $ID --mkfs --mkkey
ceph auth add osd.$ID osd 'allow *' mon 'allow rwx' -i $MOUNTPOINT/keyring

##############################################################################
# 5/5 Update fstab

echo $PARTITION $MOUNTPOINT $FS user_xattr 0 2 >>/etc/fstab

##############################################################################
# 6/5 Extra credits! Try and start the ceph osd service
# (This requires a running monitor, which you may or may not have already.)

service ceph start osd.$ID
ceph osd in $ID

##############################################################################
# All done! Phew. You can now check everything is running the way it should.

ceph status


ceph osd tree

