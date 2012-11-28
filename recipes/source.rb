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

add_inc = []
add_lib = []
silent_define = []

# retrieve and remove the PCREDIR flag (if set)
# We need it later for OpenSSL. The flag is added again manually.
if haproxy_flags.include?("USE_PCRE=1") || haproxy_flags.include?("USE_STATIC_PCRE=1")
  pcre_dirs = haproxy_flags.select{ |flag| flag.start_with?("PCREDIR=") }
  haproxy_flags = haproxy_flags - pcre_dirs

  if pcre_dirs.any?
    pcre_dir = pcre_dirs.last.sub(/^PCREDIR=/, '')
  else
    # This is how HAProxy's Makefile searches for the PCRE path
    pcre_config = Chef::ShellOut.new("pcre-config --prefix")
    pcre_config.run_command
    pcre_dir = pcre_config.stdout.strip
    pcre_dir = nil if pcre_dir == ""
  end
end

if node['haproxy']['source']['flags'].include?("USE_OPENSSL=1")
  if node['haproxy']['source']['openssl_version']
    include_recipe "haproxy::openssl"

    # Normally we would add the include and lib paths into ADDLIB and ADDINC
    # but as PCRE typically lives in /usr and the PCRE definitions are added
    # before the custom definitions, we have to be a bit hacky here.
    # We have to make sure, that the custom OpenSSL paths are inserted before
    # any system paths to make sure that gcc always uses our own OpenSSL.
    #
    # The include path is added in SILENT_DEFINE to make sure it is
    # included rather early. As DEFINE and SILENT_DEFINE are not passed to the
    # linker, we have to perform the little trick: if PCRE is used, we "hack"
    # the PCREDIR override to also include the OpenSSL lib path before the
    # PCRE lib path.

    silent_define << "-I#{node['haproxy']['source']['dir']}/openssl/include"
    if pcre_dir
      pcre_dir = "#{node['haproxy']['source']['dir']}/openssl/lib -L#{pcre_dir}"
    else
      add_lib << "-L#{node['haproxy']['source']['dir']}/openssl/lib"
    end
    # required on my Debian Wheezy test box
    add_lib << "-lz" << "-ldl"
  else
    package value_for_platform(
      %w[debian ubuntu] => {"default" => "libssl-dev"},
      %w[redhat centos fedora suse] => {"default" => "openssl-devel"},
      "default" => "libssl-dev"
    )
  end
end

haproxy_flags += node['haproxy']['source']['flags']
haproxy_flags << "PCREDIR=#{pcre_dir}"
haproxy_flags << "DEFINE=#{node['haproxy']['source']['define_flags'].join(" ")}"
haproxy_flags << "SILENT_DEFINE=#{(node['haproxy']['source']['silent_define_flags'] + silent_define).join(" ")}"
haproxy_flags << "ADDLIB=#{add_lib.join(" ")}"
haproxy_flags << "ADDINC=#{add_inc.join(" ")}"

# FIXME: This doesn't recompile if only the flags change
Chef::Log.debug("Compiling HAProxy as make #{haproxy_flags.collect {|f| Shellwords.escape(f)}.join(" ")}")
haproxy_compile = bash "compile haproxy #{version}" do
  cwd node['haproxy']['source']['dir']
  code <<-EOF
    tar -xzf #{Shellwords.escape(source_path)} -C #{Shellwords.escape(node['haproxy']['source']['dir'])}
    cd haproxy-#{version}
    make clean
    make #{haproxy_flags.collect {|f| Shellwords.escape(f)}.join(" ")}
  EOF
  creates "#{node['haproxy']['source']['dir']}/haproxy-#{version}/haproxy"
end

if Chef::Config[:solo] || node['haproxy']['source']['haproxy_compiled_flags'] == haproxy_flags
  # The flags haven't changed from the last compile attempt
  # Thus, if the compilation succeeded last time, we can skip it now
  haproxy_compile.creates "#{node['haproxy']['source']['dir']}/haproxy-#{version}/haproxy"
else
  # Flags have changed. Thus we need to perform a full clean compile run
  # We also remember the flags for next time
  node.set['haproxy']['source']['haproxy_compiled_flags'] = haproxy_flags
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
