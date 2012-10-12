include_recipe "build-essential"

# Deinstall an existing haproxy package as we most probably would conflict
package "haproxy" do
  action :purge
end

value_for_platform(
  %w[debian ubuntu] => {"default" => %w[libpcre3-dev]},
  %w[redhat centos fedora suse] => {"default" => %w[pcre-devel]},
  %w[openbsd freebsd solaris] => {"default" => %w[pcre]},
  "default" => %w[libpcre3-dev]
).each do |pkg|
  package pkg
end

add_inc = []
add_lib = []

directory node['haproxy']['source']['dir'] do
  owner "root"
  group "root"
  mode "0755"
  recursive true
end

if node['haproxy']['source']['flags'].include?("USE_OPENSSL=1")
  if node['haproxy']['source']['openssl_version']
    include_recipe "haproxy::openssl"

    add_inc << "-I#{node['haproxy']['source']['dir']}/openssl/include"
    add_lib << "-L#{node['haproxy']['source']['dir']}/openssl/lib"
  else
    package value_for_platform(
      %w[debian ubuntu] => {"default" => "libssl-dev"},
      %w[redhat centos fedora suse] => {"default" => "openssl-devel"},
      "default" => "libssl-dev"
    )
  end
end

version = node['haproxy']['source']['version']
haproxy_url = node['haproxy']['source']['url'] || begin
  major = version.match(/\d+\.\d+/)[0]

  if snapshot = version.match(/\d{8}$/)
    # For development snapshots, assuming a version string of
    # something like 1.5-20121010.
    # We need the major version in there.
    snapshot = snapshot[0] # to extract the snapshot date from the match object
    version = "ss-#{snapshot}"
    "http://haproxy.1wt.eu/download/#{major}/src/snapshot/haproxy-ss-#{snapshot}.tar.gz"
  elsif version.include?('dev')
    "http://haproxy.1wt.eu/download/#{major}/src/devel/haproxy-#{version}.tar.gz"
  else
    "http://haproxy.1wt.eu/download/#{major}/src/haproxy-#{version}.tar.gz"
  end
end

source_path = "#{Chef::Config[:file_cache_path]}/haproxy-#{version}.tar.gz"
remote_file source_path do
  source haproxy_url
  checksum node['haproxy']['source']['checksum']
  backup false
end

# Set the default make flags. These can all be overridden by setting
# node['haproxy']['source']['flags']

haproxy_flags = []
case node['os']
when "linux"
  kernel_version = Gem::Version.new node['kernel']['release'].to_s.split(".")[0..2].map(&:to_i).join(".")

  case
  when kernel_version < Gem::Version.new("2.4")
    haproxy_flags << "TARGET=linux22"
  when kernel_version <= Gem::Version.new("2.4.21")
    haproxy_flags << "TARGET=linux24"
  when kernel_version < Gem::Version.new("2.6")
    haproxy_flags << "TARGET=linux24e"
  when kernel_version < Gem::Version.new("2.6.28")
    haproxy_flags << "TARGET=linux26"
  when kernel_version >= Gem::Version.new("2.6.28")
    haproxy_flags << "TARGET=linux2628"
  end
  # Use dynamic PCRE by default
  haproxy_flags << "USE_PCRE=1"
when "solaris"
  haproxy_flags << "TARGET=solaris"
  # static PCRE is strongly recommnded on Solaris
  haproxy_flags << "USE_STATIC_PCRE=1"

when "openbsd", "freebsd"
  haproxy_flags << "TARGET=#{platform}"
  haproxy_flags << "-f" << "Makefile.bsd"
  haproxy_flags << "REGEX=pcre"
  haproxy_flags << 'COPTS.generic="-Os -fomit-frame-pointer -mgnu"'

else
  haproxy_flags << "TARGET=#{os}"
end

case node['kernel']['machine']
when "i586", "i686"
  haproxy_flags << "CPU=#{node['kernel']['machine']}"
  haproxy_flags << "ARCH=#{node['kernel']['machine']}"
  haproxy_flags << "USE_REGPARM=1"
when "x86_64"
  haproxy_flags << "CPU=generic"
  haproxy_flags << "ARCH=x86_64"
when /sparc/
  haproxy_flags << "CPU=ultrasparc"
end

haproxy_flags += node['haproxy']['source']['flags']
haproxy_flags << "DEFINE=#{node['haproxy']['source']['define_flags'].join("")}"
haproxy_flags << "SILENT_DEFINE=#{node['haproxy']['source']['silent_define_flags'].join("")}"
haproxy_flags << "ADDLIB=#{add_lib}"
haproxy_flags << "ADDINC=#{add_inc}"

# FIXME: This doesn't recompile if only the flags change
bash "compile haproxy #{version}" do
  cwd node['haproxy']['source']['dir']
  code <<-EOF
    tar -xzf #{Shellwords.escape(source_path)} -C #{Shellwords.escape(node['haproxy']['source']['dir'])}
    cd haproxy-#{version}
    make clean
    make #{haproxy_flags.collect {|f| Shellwords.escape(f)}.join(" ")}
  EOF
  creates "#{node['haproxy']['source']['dir']}/haproxy-#{version}/haproxy"
end

group "haproxy" do
  system true
end
user "haproxy" do
  comment "HAProxy"
  gid "haproxy"

  system true
  home node['haproxy']['global']['chroot']
  shell "/bin/false"
end

# Install the current version of the executable system-wide
link "/usr/sbin/haproxy" do
  to "#{node['haproxy']['source']['dir']}/haproxy-#{version}/haproxy"
end

# Install the current version of the man-page system wide
file "#{node['haproxy']['source']['dir']}/haproxy-#{version}/doc/haproxy.1" do
  mode "0644"
end
link "/usr/share/man/man1/haproxy.1" do
  to "#{node['haproxy']['source']['dir']}/haproxy-#{version}/doc/haproxy.1"
end
