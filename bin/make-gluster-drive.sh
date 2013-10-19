#!/bin/bash

PV=(`pvdisplay -c | cut -f1 -d: | tr -d ' '`) #split into array:
                                              #implicitly only use one value
VGROUP=(`pvdisplay -c | cut -f2 -d: | tr -d ' '`) #this should be the right one
NAME=gluster
DISK=/dev/$VGROUP/$NAME
PARTITION=/dev/mapper/${VGROUP}-${NAME}
FS=ext4
ALLOC_SIZE=300 #GB; min(brick) > max(vm)

ID=0
MOUNTPOINT=/
while [ -d $MOUNTPOINT ]; do
  ID=$(($ID+1))
  MOUNTPOINT=/export/brick${ID}/$NAME
done

PROMPT="Hit Enter to proceed, Ctrl-C to abort: "

################################################################################
# -1/5 Sanity checks!

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

# The logical volume already exists
if (lvdisplay -c | grep -q "/${NAME}:")
  then
  NAME_WARN="already exists!"
  PROMPT="Hit Ctrl-C to abort (press Enter if you're feeling lucky): "
else
  NAME_WARN="LGTM"
fi

echo "##############################################################################"
echo "# 0/5 Configuration"
echo

column -nts~ << EOF
Variable~Meaning~Value~Notes
~
\$PV~Physical volume~$PV~$PV_WARN
\$VGROUP~Volume group~$VGROUP~lgtm
\$NAME~Logical volume~$NAME~$NAME_WARN
\$ALLOC_SIZE~Allocation size~$ALLOC_SIZE GB~$ALLOC_WARN
\$DISK~LV device file~$DISK~lgtm
\$PARTITION~Partition path~$PARTITION~lgtm
\$MOUNTPOINT~Mount point~$MOUNTPOINT~LGTM
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
# 4/5 Update fstab

echo $PARTITION $MOUNTPOINT $FS user_xattr 0 2 >>/etc/fstab

##############################################################################
# 5/5 Restarting Gluster...

service glusterfs-server restart

##############################################################################
# 6/5 Bonus points: peer probe

set +v

echo "If this is the 'master' node, you're done. Hit Ctrl-C or Enter."
read -p "Otherwise, what's that server's name? (e.g. wpeb12) "

set +u
set -v

ssh $REPLY gluster peer probe `hostname`
