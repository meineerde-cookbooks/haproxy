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

# Unpack the sources and compile them
# Then install the result to /opt/haproxy/openssl.

config_flags = node['haproxy']['source']['openssl_config_flags']
config_flags += ["--openssldir=#{node['haproxy']['source']['dir']}/openssl"]
config_flags.delete_if {|flag| flag =~ /^\s--(prefix|openssldir)=/ }

bash "Compile OpenSSL #{version}" do
  cwd node['haproxy']['source']['dir']
  code <<-EOF
    tar -xzf #{Shellwords.escape(source_path)} -C #{Shellwords.escape(node['haproxy']['source']['dir'])}
    cd openssl-#{version}
    make clean
    ./config #{config_flags.collect {|f| Shellwords.escape(f)}.join(" ")}
    make

    # Install OpenSSL
    rm -rf ../openssl
    make test
    make install
  EOF

  creates "#{node['haproxy']['source']['dir']}/openssl-#{version}/libssl.a"
end
