#!/usr/bin/env ruby

# 2015 Jon Suderman
# https://github.com/suderman/app/

require 'rubygems'
require 'optparse'
require 'fileutils'
include FileUtils

# Install an OS X package
class App

  def initialize(source, target, options)
    @target = target
    @options = options

    # Path to temp directory
    @tmp_path = "/tmp/#{File.basename(filename(source), '.*')}"

    # Stop if the the app has already been installed
    if installed? @options[:check]
      puts blue('Found existing ') + gray(@options[:check]) 
    else

      # Check if source is homebrew, cask or Mac App Store 
      match_brew = source.match(/^brew\/([\w\-\/]+)/)
      match_cask = source.match(/^cask\/([\w\-\/]+)/)
      match_mas = source.match(/([^\/]+\/id\d+)/)

      # Install with brew 
      if match_brew
        package = match_brew.to_a.last.gsub('_',' ')  
        puts blue('brew install --force ') + gray(package)
        puts `brew install --force #{package}`.strip

      # Install with cask 
      elsif match_cask
        package = match_cask.to_a.last.gsub('_',' ')  
        puts blue('brew cask install --force ') + gray(package)
        puts `brew cask install --force #{package}`.strip

      # Install with  Mac App Store 
      elsif match_mas
        macappstore "#{installers_mas}#{match_mas.to_s}"  

      else
        unless File.file? source

          # Perhaps the source exists locally?
          unless installers_path.empty?
            # local_search = `find "#{installers_path}" -iname "#{filename(source)}" | head -n 1`.strip
            local_search = `mdfind -onlyin '#{installers_path}' '(kMDItemFSName==\"#{filename(source)}\")' | head -n 1`.strip

            # if found locally, update the source to the path
            unless local_search.empty?
              source = local_search
              found_locally = true
            end
          end

          unless found_locally
            source = "#{installers_url}#{source}" unless source.match(/^(http|ftp)/)

            # Source is a URL
            if source.match(/^(http|ftp)/)
              url = source

              download_path = "#{@tmp_path}/download"
              mkdir download_path

              source = "#{download_path}/#{filename(url)}"
              `curl #{client_certificate} "#{url}" -o "#{source}"`

            end
          end
        end

        source = File.expand_path source

        if File.file? source
          puts blue('Source ') + gray(source)
          install [source]	
        else
          puts blue('Source not found!')
        end

      end
    end
  end

  # Recursively walk through each source
  def install(sources)
    sources.each do |source|	

      # Determine what kind of file we're dealing with
      case this_kind_of source 

      # Go deeper on directories
      when :dir
        install new_sources(source)


      # Unzip contents and go deeper
      when :zip
        unzip_path = "#{@tmp_path}/unzip"
        mkdir unzip_path
        cd unzip_path

        # Unzip source
        `unzip -o "#{source}"`
        puts blue('Unzipped ') + gray(source) + blue(' to ') + gray(unzip_path)

        # Look for more sources inside
        install new_sources(unzip_path)


      # Mount disk images and go deeper
      when :dmg
        volume = `yes | hdiutil attach "#{source}" | grep /Volumes/`.split('/Volumes/').last.strip
        volume_path = "/Volumes/#{volume}"
        puts blue('Mounted ') + gray(source) + blue(' to ') + gray(volume_path)

        # Look for more sources inside
        install new_sources(volume_path)

        # Unmount volume (or at least try to)
        output = `hdiutil detach "#{volume_path}" 2>&1`
        puts blue('Unmounted ') + gray(volume_path) unless output.match(/(detach failed|couldn't unmount)/i)


      # Copy app files to the Applications directory (or open them)
      when :app
        mkdir applications_path

        if @options[:open]
          open source
        else 
          cp source, applications_path 
        end

      # Run the installer on package files
      when :pkg, :mpkg
        mkdir packages_path

        # First try to run the installer without sudo
        package = 'Package '
        output = `installer -pkg "#{source}" -target "#{packages_path}" 2>&1`

        # Should that fail, go full-sudo
        if output.match(/run as root/i)
          package = 'Package (sudo) '
          output = `sudo installer -pkg "#{source}" -target "#{packages_path}" 2>&1`
        end

        puts blue(package) + gray(source)
        puts output


      # Copy service files to the Library
      when :service
        mkdir services_path

        if @options[:open]
          open source
        else
          cp source, services_path
        end


      # Copy prefpane files to the Library
      when :prefpane
        mkdir preference_panes_path

        if @options[:open]
          open source
        else
          cp source, preference_panes_path
        end

      # Copy qlgenerator files to the Library
      when :qlgenerator
        mkdir quicklook_path

        if @options[:open]
          open source
        else
          cp source, quicklook_path
        end

      # Open safariextz files in Safari
      when :safariextz

        # Copy the safariext to a tmp directory
        copy_path = "#{@tmp_path}/copy"
        mkdir copy_path
        cp source, copy_path

        # Open the copy (Safari auto-deletes it)
        open 'Safari', "#{copy_path}/#{source}"

        puts blue('Installed ') + gray(source)

      end
    end
  end	


  # Get the file name from a path or URL (without any query strings on the end)
  def filename(source)
    fname = File.basename(source).split("#").first.split("&").first.split("?")
    fname.first.gsub("%20"," ").gsub("%2B","+")
  end


  # Determine what kind of source
  def this_kind_of(source)
    ext = File.extname(source).split('.').last
    ext = ext.downcase if ext

    # Check the extension against known extensions
    return ext.to_sym if file_types.split(',').include? ext

    # Else, check if it's a directory
    return :dir if File.directory? source

    # Else, unknown!
    :unknown
  end


  # Find new sources inside a directory
  def new_sources(path)

    # Look for known file extensions
    sources = Dir.glob "#{path}/*.{#{file_types}}" 

    # Also look for directories (that aren't black-listed)
    directories = Dir.entries(path).select do |f| 
      File.directory? "#{path}/#{f}" \
      and !(File.symlink? "#{path}/#{f}") \
      and !(f.match(/^(\.|_#{ignored_directories})/i))
    end

    # Combine files with directories (prepending full path to each directory)
    sources |= directories.each_with_index { |dir, i| directories[i] = "#{path}/#{dir}" }
  end


  # Known file types
  def file_types
    "zip,dmg,app,pkg,mpkg,service,prefpane,qlgenerator,safariextz"
  end


  # Ignored directories (from oddball installers)
  def ignored_directories
    dirs = ENV['APP_IGNORE'] || "payloads,packages,resources,deployment"
    "|#{dirs.gsub ',', '|'}"
  end

  # Does a command exist?
  def command?(name, options={})
    return false if @options[:force]
    system "type #{name} &> /dev/null"
  end

  # Has this app been installed?
  def installed?(name=false)
    return false unless name

    # With force enabled, NOTHING has been installed
    return false if @options[:force]

    # First see if the name is a command
    return true if command? name

    # Otherwise, check for different app types
    case name.split('.').last.downcase.to_sym

    when :app
      return true if find? "/Applications", name
      return true if find? "~/Applications", name
      return true if find? "~/Library/Application Support", name

    when :prefpane
      return true if find? "~/Library/PreferencePanes", name
      return true if find? "/Library/PreferencePanes", name

    when :service
      return true if find? "~/Library/Services", name
      return true if find? "/Library/Services", name

    when :plugin
      return true if find? "~/Library/Internet Plug-Ins", name
      return true if find? "/Library/Internet Plug-Ins", name

    when :qlgenerator
      return true if find? "~/Library/QuickLook", name
      return true if find? "/Library/QuickLook", name

    when :safariextz
      return true if find? "~/Library/Safari/Extensions", name

    when :fxplug
      return true if find? "/Library/Plug-Ins/FxPlug", name

    when :moef
      return true if find? "~/Movies/Motion Templates/Effects", name

    end
    false
  end

  # Copy the source file to the target directory
  def cp(source, target)

    # Cancel if existing files can't be taken care of
    return unless rm "#{target}/#{filename(source)}"

    # First try to copy sudo-free
    copied = 'Copied '
    output = `cp -R "#{source}" "#{target}" 2>&1`

    # If that doesn't work, go full-sudo
    if output.match(/permission denied/i)

      # Delete the target again, in case some files got copied
      rm "#{target}/#{filename(source)}", true

      # Sudo power!
      copied = 'Copied (sudo) '
      `sudo cp -R "#{source}" "#{target}" 2>&1`
    end

    # Report what happened
    puts blue(copied) + gray(source) + blue(' to ') + gray(target)
  end


  # Delete the target file
  def rm(target, silent=false)

    # Check if the file actually exists
    if File.exists? target
      puts blue('Found existing ') + gray(target) unless silent 

      # Politely ask if it's okay to destory this file. Leave if not.
      unless silent
        return false unless ask("Overwrite existing #{target}?")
      end

      # Attempt to the delete this file, sudo-free
      deleted = 'Deleted '
      output = `rm -rf "#{target}" 2>&1`

      # If that doesn't work, go full-sudo
      if output.match(/permission denied/i)
        deleted = 'Deleted (sudo) '
        `sudo rm -rf "#{target}" 2>&1`
      end

      # Report what happened
      puts blue(deleted) + gray(target) unless silent
    end

    # Return true unless asked to leave existing files alone
    true
  end


  # Make a directory, using sudo if needed
  def mkdir(target)
    output = `mkdir -p "#{target}" 2>&1`
    if output.match(/permission denied/i)
      `sudo mkdir -p "#{target}" 2>&1`
    end
  end

  # Check if an app exists
  def find?(path, name)

    # Ensure the path we're searching in exists
    path = File.expand_path(path)
    return false unless File.exist? path

    # Look for the file without sudo
    # find_command = "find \"#{path}\" -iname \"#{name}\" 2>&1 | head -n 1"
    find_command = "mdfind -onlyin '#{path}' '(kMDItemFSName==\"#{name}\")' | head -n 1"
    results = `#{find_command}`.chomp

    # If that doesn't work, go full-sudo
    if results.match(/permission denied/i)
      results = `sudo #{find_command}`.chomp
    end

    true unless results.empty?
  end

  # Open a file
  def open(source, args='')
    puts blue('Opening ') + gray(source)
    args = " \"#{args}\"" unless args.empty?
    `open -a "#{source}"#{args}`
  end


  # Ask for permission; skip if force is enabled
  def ask(prompt)
    return true if @options[:force]
    print yellow("#{prompt} [y/n]"), ' '
    $stdin.gets.strip.match /^y/i
  end


  # Pretty colours
  def yellow(text) "\033[33m#{text}\033[m" end
  def blue(text)   "\033[34m#{text}\033[m" end
  def gray(text)   "\033[37m#{text}\033[m" end


  # Path to where installers are stored
  def installers_path
    path = File.expand_path ENV['APP_SOURCE'] || ""
    (File.exist? path) ? path : ""
  end

  # Path to where *.app files get copied
  def applications_path 
    File.expand_path @target || "/Applications"
  end

  # Path to where *.prefpane files get copied
  def preference_panes_path
    File.expand_path @target || "~/Library/PreferencePanes"
  end

  # Path to where *.qlgenerator files get copied
  def quicklook_path
    File.expand_path @target || "~/Library/QuickLook"
  end

  # Path to where *.service files get copied
  def services_path
    File.expand_path @target || "~/Library/Services"
  end

  # Path to where *.pkg and *.mpkg files get installed
  def packages_path
    File.expand_path @target || "/"
  end

  # Name of client cert for curl downloads
  def client_certificate
    cert = ENV['DOMAIN'] ? "#{ENV['USER']}@#{ENV['DOMAIN']}" : ENV['USER']
    cert = ENV['APP_CERT'] || cert
    return (cert) ?  " -E #{cert} " : ""
  end

  # URL to where installers are stored
  def installers_url
    if ENV['APP_URL']
      "#{ENV['APP_URL']}/"
    else
      ''
    end
  end

  # URL to where installers are stored
  def installers_mas
    if ENV['APP_MAS']
      "#{ENV['APP_MAS']}/"
    else
      'macappstore://itunes.apple.com/us/app/'
    end
  end

  # Much taken from https://gist.github.com/phs/6505382
  def macappstore url
    puts blue('Mac App Store ') + gray(url)
    `open '#{url}' && sleep 2

    osascript 3<&0 <<'APPLESCRIPT'
      on run argv
        tell application "System Events"
          tell window "App Store" of process "App Store"
            set loaded to false
            repeat until loaded = true
              try
                set installGroup to group 1 of group 1 of UI element 1 of scroll area 1 of group 1 of group 1
                set installButton to button 1 of installGroup
                set loaded to true
              on error
                delay 1
              end try
            end repeat
            
            if description of installButton contains "Install" and description of installButton contains "Free" then
              click installButton
            else
              tell application "App Store" to quit
              return
            end if
            
            set installed to false
            repeat until installed = true
              delay 5
              set installButton to button 1 of installGroup
              if description of installButton contains "Open," then
                set installed to true
              end if
            end repeat
            
            tell application "App Store" to quit
            return
            
          end tell
        end tell
      end run
APPLESCRIPT`
  end
end


# Default values for options
options = { :check => false, :open => false, :force => false, :help => false }

# Option parser
opt_parser = OptionParser.new do |opt|
  opt.banner = "Usage: app [OPTIONS] SOURCE [TARGET]"
  opt.on("-c","--check DESTINATION","First check if installed") { |dest| options[:check] = dest }
  opt.on("-o","--open","Open app from source (instead of copying to target)") { options[:open] = true }
  opt.on("-f","--force","Force existing apps to be overwritten") { options[:force] = true }
  opt.on("-h","--help","help") { options[:help] = true }
end

opt_parser.parse!


# If there's an argument, let's do this:
if ARGV[0]
  source = ARGV[0]
  target = ARGV[1] || nil
  App.new source, target, options

# If there's no arguments, show the help
else
  options[:help] = true
end

puts opt_parser if options[:help]
