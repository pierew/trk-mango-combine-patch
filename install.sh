#!/bin/bash
echo "Install Mango"
cp ./mango /bin/mango
chmod +x /bin/mango
echo "Replace trkmenu"
cp ./trkmenu /bin/trkmenu
chmod +x /bin/trkmenu
echo "Replace trkbootnet"
cp ./trkbootnet /bin/trkbootnet
chmod +x /bin/trkbootnet
echo "Replace mountcd.sh"
cp ./mountcd.sh /etc/mountcd.sh
chmod +x /etc/mountcd.sh
echo "Install tune2fs"
cp ./tune2fs /bin/tune2fs
chmod +x /bin/tune2fs
