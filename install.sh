#!/bin/sh

# 2012 Jon Suderman
# https://github.com/suderman/symlink/

# Open a terminal and run this command:
# curl https://raw.github.com/suderman/app/master/install.sh | sh

# Ensure /usr/local/bin exists
if [ ! -d "/usr/local" ]; then
  sudo mkdir -p /usr/local/bin
  sudo chown `whoami`:admin /usr/{local,local/bin}
fi

# Download app into /usr/local/bin
curl https://raw.github.com/suderman/app/master/app -o /usr/local/bin/app

# Set permissions
chmod +x /usr/local/bin/app

echo "Installed app to /usr/local/bin"
