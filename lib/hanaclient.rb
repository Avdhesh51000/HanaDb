require 'dbcapi'
current_dir = File.dirname(__FILE__)
if RbConfig::CONFIG['arch'] =~ /mingw/
  begin
    RubyInstaller::Runtime.add_dll_directory(current_dir)
  rescue
    unless ENV['PATH'].include?(current_dir)

      $stderr.puts "Temporarily enhancing PATH by #{current_dir}..." if $DEBUG

      ENV['PATH'] = current_dir + ";" + ENV['PATH']
    end
  end
end
module HANACLIENT
  include DBCAPI
end
