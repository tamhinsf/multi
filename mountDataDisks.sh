mntBasePath=/mnt

sudo yum install lsscsi -y
for device in `lsscsi |grep -v "/dev/sda \|/dev/sdb \|/dev/sr0 " | cut -d "/" -f3`; do 
  mkfs -F -t ext4 /dev/$device
  mkdir -p $mntBasePath/$device
  echo "UUID=`blkid -s UUID /dev/$device | cut -d '"' -f2` $mntBasePath/$device ext4  barrier=0,defaults,discard 0 0" | tee -a /etc/fstab 
done

sudo mount -a

# echo done
exit 0