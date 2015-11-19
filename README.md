app
===

OS X installer for URLs ending in `zip`, `dmg`, `pkg`, `mpkg`, `service`, `prefPane`, `safariextz`  

Intended to simplify the installation of OS X apps in the same way 
[Homebrew](http://mxcl.github.com/homebrew/), [RubyGems](http://rubygems.org/), and 
[npm](http://npmjs.org/) has made our lives easier.  For example, if I wanted to install 
Google Chrome, I could type:  

`app https://dl.google.com/chrome/mac/stable/GGRO/googlechrome.dmg`  

Or, if the installer is already in my Downloads:  

`app ~/Downloads/googlechrome.dmg`  

Or, if I had set an installer directory or URL (see [customize](#customize) below):  

`app googlechrome.dmg`  

The installation of apps in the Mac App Store can be automated with the proper App Store URL 
or shortened ID:  

`app amphetamine/id937984704` 

Additionally, this can work as a wrapper for `brew` and `brew cask` install commands. Simply 
preface the package name with brew/ or cask/ to initiate the install:  

`app brew/wget`  
`app cask/firefox`  

Install
-------
Open a terminal and run this command:  

`curl https://raw.githubusercontent.com/suderman/app/master/install.sh | sh`

### Or, clone the repo
Download and copy `app` somewhere in your path, ie: 

`git clone https://github.com/suderman/app.git`  
`cp app/app /usr/local/bin`  

Options
-------
Although app tries to put stuff where it belongs (ie: .app files
go in the /Applications directory), you can override this by passing a second 
target parameter:  

`app googlechrome.dmg ~/Applications`  

Also, app is polite and won't overwrite existing files without
asking. You can skip this by passing the -f option:  

`app -f googlechrome.dmg`  

Some installers are .app files that need to be opened directly. Passing 
the -o option will not copy anything, but instead open the installer within 
the disk image:  

`app -o Photoshop_13_LS16-1.dmg`  

If you know the filename of the installed application, you can check if it 
already exists before downloading and installing. Passing the -c option along
with a filename will check the expected destinations and stop if it's found:  

`app 'Firefox 42.0.dmg' -c Firefox.app`  

Customize
---------
app has a couple customizations available via enironment
variables:

### Look for installers in a local directory
Set `APP_SOURCE` to a directory on your local disk. You can still
install via URL, but if a matching file is found within this directory 
(or sub-directory), the local copy will be used instead. For example:  

`APP_SOURCE=~/Downloads`  

### Look for installers at a URL
Set `APP_URL` to the URL of a website hosting your installers. You can 
still install via other URLs, but this allows for short-form URL 
installations, skipping right to the directory/file. For example:  

`APP_URL=https://www.mywebsite.com/installers`  

### Client Certificate
When downloading from an https:// URL, you may have your installers
protected via client certificate authentication. In such case, curl will 
attempt to use a client certificate in your OS X Keychain based on your 
$USER env variable, or $USER@$DOMAIN if exists. You can explicity set
which certificate to use with `APP_CERT`. For example:  

`APP_CERT=homer@simpson.com`  

### Mac App Store URL
When installing from the Mac App Store, a short form of the URL can be 
used (name-of-application/id123456789). The default URL is the US store, so
be sure to set `APP_MAS` to your country's URL. For example:  

`APP_MAS=macappstore://itunes.apple.com/ca/app`  

### Ignore specific installer directories
Set `APP_IGNORE` to a comma-separated list of directories you
don't want app to look at. Although the default setting takes care 
of a few odd-ball installers, you may discover others that require 
custom filters. This example shows the default setting:  

`APP_IGNORE=payloads,packages,resources,deployment`

See Also
--------
- [Homebrew](http://brew.sh/)  
- [Homebrew Cask](http://caskroom.io/)  
