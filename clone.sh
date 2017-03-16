#!/bin/sh  
  
  
# user variables  
SourceVM="debian-1"
SourceVMID=76
SourceDS="/vmfs/volumes/4kVMS"  
DestDS="/vmfs/volumes/4kVMS"  
ScriptDIR="/scripts"  
  
  
######################################################################################  
# Do NOT modify anything beyond this point, unless you know what you are doing  
######################################################################################  
  
  
# script variables  
DestVM="debian-$1"  
ScriptRunTime=$(date "+%Y%m%d_%H%M")  
nicfile=$ScriptDIR/nic_$DestVM.txt  
diskfile=$ScriptDIR/disk_$DestVM.txt  
  
  
# create destination directory  
mkdir $DestDS/$DestVM  
  
  
# copy source vmx? files to destination  
cp $SourceDS/$SourceVM/$SourceVM.vmx $DestDS/$DestVM/$DestVM.vmx  
sed -i "s/$SourceVM/$DestVM/g" $DestDS/$DestVM/$DestVM.vmx  
  
  
cp $SourceDS/$SourceVM/$SourceVM.vmxf $DestDS/$DestVM/$DestVM.vmxf  
sed -i "s/$SourceVM/$DestVM/g" $DestDS/$DestVM/$DestVM.vmxf  
  
  
# create snapshot from source  
vim-cmd vmsvc/snapshot.create $SourceVMID HotClone_$ScriptRunTime HotClone_of_$SourceVM 0 0  
  
# Search for Disks  
rm $diskfile > /dev/null 2>&1  
while read line ; do  
  grep ".vmdk" | awk '{ print $3}' | sed "s/\"//g" >> $diskfile  
done < $DestDS/$DestVM/$DestVM.vmx  
  
  
# copy sourcedisk to destinationdisk (thin provisioned)  
while read line ; do  
  vmkfstools -d thin -i $SourceDS/$SourceVM/$(echo $line | sed "s/$DestVM/$SourceVM/g") $DestDS/$DestVM/$(echo $line | sed 's/-[0-9]*//g')  
done < $diskfile  
  
  
# If Source already had a snapshot, remove snapdata on vmdk filename in vmx-file  
sed -i "s/\(.*\)\-.*\(.vmdk\)/\1\2/g" $DestDS/$DestVM/$DestVM.vmx
sed -i "s/\(.*\)\-.*\(.vmdk\)/\1\2/g" $DestDS/$DestVM/$DestVM.vmx  
  
# Search for nics   
rm $nicfile > /dev/null 2>&1  
while read line ; do  
  grep ethernet[0-9].virtualDev | awk '{ print $1}' | sed "s/.virtualDev//g" >> $nicfile  
done < $DestDS/$DestVM/$DestVM.vmx  
  
  
# register destination VM in inventory  
DestVMID=`vim-cmd solo/registervm $DestDS/$DestVM/$DestVM.vmx`  
  
  
# Powering up destination virtual machine  
vim-cmd vmsvc/power.on $DestVMID &  
sleep 15  
vim-cmd vmsvc/message $DestVMID _vmx1 2  
 
  
# Remove HotClone Snapshot from source  
SnapToRemove=`vim-cmd vmsvc/snapshot.get $SourceVMID | grep -A 1 HotClone_$ScriptRunTime | grep -e "Id" | awk '{print $4 }'`  
vim-cmd vmsvc/snapshot.remove $SourceVMID $SnapToRemove 0  
  
  
# EOF  
