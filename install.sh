#!/bin/sh
# curl https://raw.github.com/suderman/app/master/install.sh | sh

# Download app into /usr/local/bin
curl https://raw.github.com/suderman/app/master/app -o /usr/local/bin/app

# Set permissions
chmod +x /usr/local/bin/app

echo "Installed app to /usr/local/bin"
