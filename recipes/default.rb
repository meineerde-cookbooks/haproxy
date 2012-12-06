case node['haproxy']['install_method']
when 'source'
  include_recipe "haproxy::source"
when 'package'
  package "haproxy" do
    action :install
  end
end

directory node['haproxy']['dir'] do
  owner "root"
  group "root"
  mode "0755"
  recursive true
end

template "/etc/default/haproxy" do
  source "haproxy.default.erb"
  owner "root"
  group "root"
  mode "0644"
end

settings = {}

### GLOBAL SETTINGS
settings['global'] = node['haproxy']['global'].to_hash

if settings['global']['daemon'].nil?
  # only enable the daemon mode if we use SysV Init
  settings['global']['daemon'] = (node['haproxy']['init_style'] == "init") || settings['global']['nbproc'] > 1
end

settings['global']['stats socket'] = [].tap do |s|
  s << node['haproxy']['global']['stats socket']['path']
  s << "user" << (node['haproxy']['global']['stats socket']['user'] || node['haproxy']['global']['user'])
  s << "group" << (node['haproxy']['global']['stats socket']['group'] || node['haproxy']['global']['group'])
  s << "mode" << node['haproxy']['global']['stats socket']['mode']
  s << "level" << node['haproxy']['global']['stats socket']['level']
  s
end.join(" ")

settings['global']['node'] ||= node['fqdn']

### DEFAULT SETTINGS
settings['defaults'] = node['haproxy']['defaults'].to_hash

%w[global defaults].each do |cfg_type|
  template File.join(node['haproxy']['dir'], "#{cfg_type}.cfg") do
    source "key_value.erb"
    variables :data => settings[cfg_type]

    owner "root"
    group "root"
    mode "0644"
  end
end

%w[frontend.d backend.d listen.d].each do |dir|
  directory File.join(node['haproxy']['dir'], dir) do
    owner "root"
    group "root"
    mode "0755"
  end
end

directory node['haproxy']['ssl_dir'] do
  owner "root"
  group "root"
  mode "0750"
end

# "Empty" chroot directory
# This should only contain HAProxy's UNIX sockets
directory node['haproxy']['global']['chroot'] do
  owner "root"
  group "root"
  mode "755"
  recursive true
end

cookbook_file "/usr/sbin/haproxy_join" do
  source "haproxy_join"

  owner "root"
  group "root"
  mode "0755"
end

case node['haproxy']['init_style']
when 'init'
  template "/etc/init.d/haproxy" do
    source "haproxy.init.erb"
    owner "root"
    group "root"
    mode "0755"
  end

  service "haproxy" do
    supports :reload => true
    action [ :enable ]
  end
when 'runit'
  include_recipe "runit"

  runit_service "haproxy" do
    action [ :enable ]
    # FIXME: Add support for reload
  end
end
