installion
==========

OS X installer for URLs ending in `zip`, `dmg`, `pkg`, `mpkg`, `service`, `prefPane`, `safariextz`  

Intended to simplify the installation of OS X apps in the same way 
[Homebrew](http://mxcl.github.com/homebrew/), [RubyGems](http://rubygems.org/), and 
[npm](http://npmjs.org/) has made our lives easier.  For example, if I wanted to install 
Google Chrome, I could type:  

`installion https://dl.google.com/chrome/mac/stable/GGRO/googlechrome.dmg`  

Or, if the installer is already in my Downloads:  

`installion ~/Downloads/googlechrome.dmg`  

Or, if I had set an installer directory (see customizations below):  

`installion googlechrome.dmg`  

Install Manually
----------------
Download and copy `installion` somewhere in your path, ie: 

`git clone https://github.com/suderman/installion.git`  
`cp installion/installion /usr/local/bin`  

Install with Homebrew
-----------------------
Tap my [Homebrew repository](https://github.com/suderman/homebrew-suds) and install:  

`brew tap suderman/suds`  
`brew install installion`  

You can also install via URL:

`brew install https://raw.github.com/suderman/homebrew-suds/master/installion.rb`  

Customize
---------
installion has a couple customizations available via enironment
variables.

### Look for installers in a local directory
Set `INSTALLION_SOURCE` to a directory on your local disk. You can still
install via URL, but if a matching file is found within this directory 
(or sub-directory), the local copy will be used instead. For example:  

`INSTALLION_SOURCE=~/Downloads`

### Ignore specific installer directories
Set `INSTALLION_IGNORE` to a comma-separated list of directories you
don't want installion to look at. Although the default setting takes care 
of a few odd-ball installers, you may discover others that require 
custom filters. This example shows the default setting:  

`INSTALLION_IGNORE=payloads,packages,resources,deployment`

