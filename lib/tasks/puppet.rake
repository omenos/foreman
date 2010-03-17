# Author: Roberto Moral Denche (Telmo : telmox@gmail.com)
# Description: The tasks defined in this Rakefile will help you populate some of the
#    fields in Foreman with what is already present in your database from
#    StoragedConfig.
require 'rake/clean'

namespace :puppet do
  root    = "/"
  # Author: Paul Kelly (paul.ian.kelly@gogglemail.com)
  # Description: The tasks defined in this namespace populate a directory structure with rdocs for the
  # clases defined in puppet.
  namespace :rdoc do
    desc "
    Populates the rdoc tree with information about all the classes in your modules."
    task :generate => [:environment, :prepare] do
      Puppetclass.rdoc root
    end
    desc "
    Optionally creates a copy of the current puppet modules and sanitizes it.
    It should return the directory into which it has copied the cleaned modules"
    task :prepare => :environment do
      root = Puppetclass.prepare_rdoc root
    end
  end
  namespace :migrate do
    desc "Populates the host fields in Foreman based on your StoredConfig DB"
    task :populate_hosts => :environment do
      counter = 0
      Host.find_each do |host|
        if host.fact_values.size == 0
          $stdout.puts "#{host.hostname} has no facts, skipping"
          next
        end

        if host.populateFieldsFromFacts
          counter += 1
        else
          $stdout.puts "#{host.hostname}: #{host.errors.full_messages.join(", ")}"
        end
      end
      puts "Imported #{counter} hosts out of #{Host.count} Hosts" unless counter == 0
    end
  end
  namespace :import do
    desc "Imports hosts and facts from existings YAML files, use dir= to override default directory"
    task :hosts_and_facts => :environment do
      dir = ENV['dir'] || "#{Puppet[:vardir]}/yaml/facts"
      puts "Importing from #{dir}"
      Dir["#{dir}/*.yaml"].each do |yaml|
        name = yaml.match(/.*\/(.*).yaml/)[1]
        puts "Importing #{name}"
        Host.importHostAndFacts File.read yaml
      end
    end
  end
  #TODO: remove old classes
  namespace :import do
    desc "Update puppet environments and classes"
    task :puppet_classes => :environment do
      ec, pc = Environment.count, Puppetclass.count
      Environment.importClasses
      puts "Environment   old:#{ec}\tcurrent:#{Environment.count}"
      puts "PuppetClasses old:#{pc}\tcurrent:#{Puppetclass.count}"
    end
  end
  namespace :import do
    desc "
    Import your hosts classes and parameters classifications from another external node source.
    define script=/dir/node as the script which provides the external nodes information.
    This will only scan for hosts that already exists in our database, if you want to
    import hosts, use one of the other importers.
    YOU Must import your classes first!"

    task :external_nodes => :environment do
      if Puppetclass.count == 0
        $stdout.puts "You dont have any classes defined.. aborting!"
        exit(1)
      end

      if (script = ENV['script']).nil?
        $stdout.puts "You must define the old external nodes script to use. script=/path/node"
        exit(1)
      end

      Host.find_each do |host|
        $stdout.print "processing #{host.name} "
        nodeinfo = YAML::load %x{#{script} #{host.name}}
        if nodeinfo.is_a?(Hash)
          $stdout.puts "DONE" if host.importNode nodeinfo
        else
          $stdout.puts "ERROR: invalid output from external nodes"
        end
        $stdout.flush
      end

    end
  end

end
