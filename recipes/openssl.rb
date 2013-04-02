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

# Default flags from Debian Wheezy
config_flags = ["no-idea", "no-mdc2", "no-rc5", "zlib", "enable-tlsext", "no-ssl2"]
config_flags += node['haproxy']['source']['openssl_config_flags']

# We set the target by ourself and don't want anyone messing with us.
config_flags.delete_if {|flag| flag =~ /^\s*--(prefix|openssldir)=/ }
config_flags += ["--openssldir=#{node['haproxy']['source']['dir']}/openssl"]

config_flags_for_shell = config_flags.collect {|f| Shellwords.escape(f)}.join(" ")

# Unpack the sources and compile them
# Then install the result to /opt/haproxy/openssl.
Chef::Log.debug("Compiling OpenSSL #{version} as: make #{config_flags_for_shell}")
openssl_compile = bash "Compile OpenSSL #{version}" do
  cwd node['haproxy']['source']['dir']
  code <<-EOF
    set -e

    tar -xzf #{Shellwords.escape(source_path)} -C #{Shellwords.escape(node['haproxy']['source']['dir'])}
    cd openssl-#{version}
    make clean
    ./config #{config_flags_for_shell}
    make

    # Install OpenSSL
    rm -rf ../openssl
    make test
    make install
  EOF
end
if Chef::Config[:solo] || !node['haproxy']['source']['openssl_compiled_config_flags'] || node['haproxy']['source']['openssl_compiled_config_flags'] == config_flags_for_shell
  # The flags haven't changed from the last compile attempt
  # Thus, if the compilation succeeded last time, we can skip it now
  openssl_compile.not_if do
    have_openssl = (
      File.exists?("#{node['haproxy']['source']['dir']}/openssl-#{version}/libssl.a") &&
      File.exists?("#{node['haproxy']['source']['dir']}/openssl/lib/libssl.a")
    )

    node.run_state['force_haproxy_compilation'] = !have_openssl
    have_openssl
  end
else
  # Flags have changed. Thus we need to perform a full clean compile run
  # We also remember the flags for next time
  node.set['haproxy']['source']['openssl_compiled_config_flags'] = config_flags_for_shell
  node.run_state['force_haproxy_compilation'] = true
end
