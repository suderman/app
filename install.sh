#!/bin/sh

# 2015 Jon Suderman
# https://github.com/suderman/app/

# Open a terminal and run this command:
# curl https://raw.githubusercontent.com/suderman/app/master/install.sh | sh

# Ensure /usr/local/bin exists
if [ ! -d "/usr/local" ]; then
  sudo mkdir -p /usr/local/bin
  ULB_OWNER=`whoami`:`ls -ld /usr | awk '{print $4}'`
  sudo chown $ULB_OWNER /usr/{local,local/bin}
fi

# Download app into /usr/local/bin
sudo curl https://raw.githubusercontent.com/suderman/app/master/app -o /usr/local/bin/app

# Set permissions
ULB_OWNER=`ls -ld /usr/local/bin | awk '{print $3}'`:`ls -ld /usr/local/bin | awk '{print $4}'`
sudo chown $ULB_OWNER /usr/local/bin/app 
sudo chmod +x /usr/local/bin/app

echo "Installed app to /usr/local/bin"

