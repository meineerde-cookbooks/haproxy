include_recipe "build-essential"
require "shellwords"

# Deinstall an existing haproxy package as we most probably would conflict
package "haproxy" do
  action :purge
end

directory node['haproxy']['source']['dir'] do
  owner "root"
  group "root"
  mode "0755"
  recursive true
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
    "#{node['haproxy']['source']['base_url']}/#{major}/src/snapshot/haproxy-ss-#{snapshot}.tar.gz"
  elsif version.include?('dev')
    "#{node['haproxy']['source']['base_url']}/#{major}/src/devel/haproxy-#{version}.tar.gz"
  else
    "#{node['haproxy']['source']['base_url']}/#{major}/src/haproxy-#{version}.tar.gz"
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
  make = "make"

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
    # getaddrinfo should be safe on recent all recent distributions
    haproxy_flags << "USE_GETADDRINFO=1"
  end
  # Use dynamic PCRE by default
  haproxy_flags << "USE_PCRE=1"
when "solaris"
  # HAProxy requires GNU make
  make = "gmake"

  haproxy_flags << "TARGET=solaris"
  # static PCRE is strongly recommnded on Solaris
  haproxy_flags << "USE_STATIC_PCRE=1"

when "openbsd", "freebsd"
  # HAProxy requires GNU make
  make = "gmake"

  haproxy_flags << "TARGET=#{platform}"
  haproxy_flags << "REGEX=pcre"
  haproxy_flags << 'COPTS.generic="-Os -fomit-frame-pointer -mgnu"'

else
  make = "make"
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

add_inc = []
add_lib = []

# Install the PCRE library and headers if required
if haproxy_flags.include?("USE_PCRE=1") || haproxy_flags.include?("USE_STATIC_PCRE=1")
  value_for_platform(
    %w[debian ubuntu] => {"default" => %w[libpcre3-dev]},
    %w[redhat centos fedora suse] => {"default" => %w[pcre-devel]},
    %w[openbsd freebsd solaris] => {"default" => %w[pcre]},
    "default" => %w[libpcre3-dev]
  ).each do |pkg|
    package pkg do
      action :install
    end
  end
end

if node['haproxy']['source']['flags'].include?("USE_OPENSSL=1")
  if node['haproxy']['source']['openssl_version']
    include_recipe "haproxy::openssl"

    haproxy_flags.delete_if {|flag| flag =~ /^\s*(SSL_INC|SSL_LIB)=/ }
    haproxy_flags << "SSL_INC=#{node['haproxy']['source']['dir']}/openssl/include"
    haproxy_flags << "SSL_LIB=#{node['haproxy']['source']['dir']}/openssl/lib"

    # required on my Debian Wheezy test box
    add_lib << "-lz" << "-ldl"
  else
    package value_for_platform_family(
      %w[debian] => "libssl-dev",
      %w[rhel fedora suse] => "openssl-devel",
      "default" => "libssl-dev"
    )
  end
end

if (node['haproxy']['source']['flags'] & %w[USE_ZLIB=1 USE_OPENSSL=1]).any?
  # Make sure we have the proper zlib headers available
  package value_for_platform(
    %w[debian] => {"default" => "zlib1g-dev"},
    %w[rhel fedora suse] => {"default" => "zlib-devel"},
    "default" => "zlib1g-dev"
  )
end

if Gem::Version.new(version) >= Gem::Version.new('1.8')
  # Make sure the -lpthraec option appears last, otherwise we might run into
  # https://github.com/haproxy/haproxy/issues/204
  add_lib << '-lpthread' unless node['haproxy']['source']['flags'].include?('USE_THREAD=')
end

haproxy_flags << "PREFIX=#{node['haproxy']['source']['dir']}/haproxy"
haproxy_flags += node['haproxy']['source']['flags']
haproxy_flags << "DEFINE=#{node['haproxy']['source']['define_flags'].join(" ")}"
haproxy_flags << "SILENT_DEFINE=#{(node['haproxy']['source']['silent_define_flags']).join(" ")}"
haproxy_flags << "ADDLIB=#{add_lib.join(" ")}"
haproxy_flags << "ADDINC=#{add_inc.join(" ")}"

previous_compiled_version = node['haproxy']['source']['haproxy_compiled_version']
previous_compiled_flags = node['haproxy']['source']['haproxy_compiled_flags']

bash "compile haproxy #{version}" do
  cwd node['haproxy']['source']['dir']
  code <<-EOF
    set -e

    rm -rf #{Shellwords.escape(node['haproxy']['source']['dir'])}/haproxy-#{version}
    tar -xzf #{Shellwords.escape(source_path)} -C #{Shellwords.escape(node['haproxy']['source']['dir'])}
    cd haproxy-#{version}
    #{make} clean
    #{make} #{haproxy_flags.collect {|f| Shellwords.escape(f)}.join(" ")}
    rm -rf #{Shellwords.escape(node['haproxy']['source']['dir'] + "/haproxy")}
    #{make} install #{haproxy_flags.collect {|f| Shellwords.escape(f)}.join(" ")}
  EOF

  if node['haproxy']['reload_on_update']
    notifies :reload, 'service[haproxy]'
  end

  extend Chef::Mixin::Checksum
  only_if do
    # some other component (e.g. openssl) forces compilation
    node.run_state['force_haproxy_compilation'] ||

    # the installed version has changed
    previous_compiled_version &&
    previous_compiled_version != version ||

    # the compile flags from last time are available and have changed
    previous_compiled_flags &&
    previous_compiled_flags != haproxy_flags ||

    # the compiled or installed binary is not where it is expected
    !File.exist?("#{node['haproxy']['source']['dir']}/haproxy-#{version}/haproxy") ||
    !File.exist?("#{node['haproxy']['source']['dir']}/haproxy/sbin/haproxy") ||

    # the compiled and installed binaries differ
    checksum("#{node['haproxy']['source']['dir']}/haproxy-#{version}/haproxy") !=
      checksum("#{node['haproxy']['source']['dir']}/haproxy/sbin/haproxy")
  end
end

# Remember the compile flags for next time
node.set['haproxy']['source']['haproxy_compiled_flags'] = haproxy_flags
node.set['haproxy']['source']['haproxy_compiled_version'] = version

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
link node['haproxy']['bin'] do
  to "#{node['haproxy']['source']['dir']}/haproxy/sbin/haproxy"
end

# Install the current version of the man-page system wide
link "/usr/share/man/man1/haproxy.1" do
  to "#{node['haproxy']['source']['dir']}/haproxy/share/man/man1/haproxy.1"
end

if Gem::Version.new(version) < Gem::Version.new('1.8')
  link node['haproxy']['systemd_wrapper_bin'] do
    to "#{node['haproxy']['source']['dir']}/haproxy/sbin/haproxy-systemd-wrapper"
  end
else
  link node['haproxy']['systemd_wrapper_bin'] do
    action :delete
  end
end
