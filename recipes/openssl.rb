# Perl is a build dependency for OpenSSL
include_recipe "perl"

version = node['haproxy']['source']['openssl_version']
source_path = "#{Chef::Config[:file_cache_path]}/openssl-#{version}.tar.gz"

# Download OpenSSL sources
remote_file source_path do
  source "http://www.openssl.org/source/openssl-#{version}.tar.gz"
  checksum node['haproxy']['source']['openssl_checksum']
  backup false
end

config_flags = ["no-ssl2", "no-shared"]
config_flags += node['haproxy']['source']['openssl_config_flags']

# We set the target by ourself and don't want anyone messing with us.
config_flags.delete_if {|flag| flag =~ /^\s*--(prefix|openssldir)=/ }
config_flags += ["--prefix=#{node['haproxy']['source']['dir']}/openssl"]

config_flags_for_shell = config_flags.collect {|f| Shellwords.escape(f)}.join(" ")

previous_compiled_config_flags = node['haproxy']['source']['openssl_compiled_config_flags']
previous_compiled_version = node['haproxy']['source']['openssl_compiled_version']

# Unpack the sources and compile them
# Then install the result to /opt/haproxy/openssl.
Chef::Log.debug("Compiling OpenSSL #{version} as: make #{config_flags_for_shell}")
openssl_compile = bash "Compile OpenSSL #{version}" do
  cwd node['haproxy']['source']['dir']
  code <<-EOF
    set -e

    rm -rf #{Shellwords.escape(node['haproxy']['source']['dir'])}/openssl-#{version}
    tar -xzf #{Shellwords.escape(source_path)} -C #{Shellwords.escape(node['haproxy']['source']['dir'])}
    cd openssl-#{version}
    ./config #{config_flags_for_shell}
    make depend
    make
    make test

    # Install OpenSSL
    rm -rf ../openssl
    make install_sw
  EOF

  extend Chef::Mixin::Checksum
  only_if do
    node.run_state['force_haproxy_compilation'] ||= begin
      # the installed version has changed
      previous_compiled_version &&
      previous_compiled_version != version ||

      # the compile flags from last time are available and have changed
      previous_compiled_config_flags &&
      previous_compiled_config_flags != config_flags_for_shell ||

      # the compiled or installed binary is not where it is expected
      !File.exist?("#{node['haproxy']['source']['dir']}/openssl-#{version}/libssl.a") ||
      !File.exist?("#{node['haproxy']['source']['dir']}/openssl/lib/libssl.a") ||

      # the compiled and installed binaries differ
      checksum("#{node['haproxy']['source']['dir']}/openssl-#{version}/apps/openssl") !=
        checksum("#{node['haproxy']['source']['dir']}/openssl/bin/openssl")
    end
  end
end

# Remember config flags for next time
node.set['haproxy']['source']['openssl_compiled_config_flags'] = config_flags_for_shell
node.set['haproxy']['source']['openssl_compiled_version'] = version
