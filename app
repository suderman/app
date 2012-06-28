#!/usr/bin/env ruby

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

    unless File.file? source

      # Perhaps the source exists locally?
      unless installers_path.empty?
        local_search = `find "#{installers_path}" -iname "#{filename(source)}" | head -n 1`.strip
        source = local_search unless local_search.empty?
      end

      # Source is a URL
      if source.match(/^(http|ftp)/)
        url = source

        download_path = "#{@tmp_path}/download"
        mkdir download_path

        source = "#{download_path}/#{filename(url)}"
        `curl "#{url}" -o "#{source}"`
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


      # Copy prefPane files to the Library
      when :prefPane
        mkdir preference_panes_path

        if @options[:open]
          open source
        else
          cp source, preference_panes_path
        end


      # Open safariextz files in Safari
      when :safariextz
        open 'Safari', source
        puts blue('Installed ') + gray(source)
      end

    end
  end	


  # Get the file name from a path or URL (without any query strings on the end)
  def filename(source)
    File.basename(source).split("#").first.split("&").first.split("?").first
  end


  # Determine what kind of source
  def this_kind_of(source)
    ext = File.extname(source).split('.').last

    # Check the extension against known extensions
    return ext.to_sym if file_types.split(',').include? ext

    # Else, check if it's a directory
    return :dir if File.directory? source

    # It's a mystery!
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
    "zip,dmg,app,pkg,mpkg,service,prefPane,safariextz"
  end


  # Ignored directories (from oddball installers)
  def ignored_directories
    dirs = ENV['APP_IGNORE'] || "payloads,packages,resources,deployment"
    "|#{dirs.gsub ',', '|'}"
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
    File.expand_path ENV['APP_SOURCE'] || ""
  end

  # Path to where *.app files get copied
  def applications_path 
    File.expand_path @target || "/Applications"
  end

  # Path to where *.prefPane files get copied
  def preference_panes_path
    File.expand_path @target || "~/Library/PreferencePanes"
  end

  # Path to where *.service files get copied
  def services_path
    File.expand_path @target || "~/Library/Services"
  end

  # Path to where *.pkg and *.mpkg files get installed
  def packages_path
    File.expand_path @target || "/"
  end

end


# Default values for options
options = { :open => false, :force => false, :help => false }

# Option parser
opt_parser = OptionParser.new do |opt|
  opt.banner = "Usage: app [OPTIONS] SOURCE [TARGET]"
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