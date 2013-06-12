case node['haproxy']['install_method']
when 'source'
  include_recipe "haproxy::source"
when 'package'
  package "haproxy" do
    action :install
    if node['haproxy']['reload_on_update']
      extend HAProxy::Helpers
      notifies haproxy_reload_action, haproxy_service_name
    end
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

if node['haproxy']['global']['daemon'].nil?
  # only enable the daemon mode if we use SysV Init
  node.override['haproxy']['global']['daemon'] = (node['haproxy']['init_style'] == "init") || node['haproxy']['global']['nbproc'] > 1
end

unless node['haproxy']['global']['stats socket'].is_a?(String)
  node.override['haproxy']['global']['stats socket'] = [].tap do |s|
    s << node['haproxy']['global']['stats socket']['path']
    s << "user" << (node['haproxy']['global']['stats socket']['user'] || node['haproxy']['global']['user'])
    s << "group" << (node['haproxy']['global']['stats socket']['group'] || node['haproxy']['global']['group'])
    s << "mode" << node['haproxy']['global']['stats socket']['mode']
    s << "level" << node['haproxy']['global']['stats socket']['level']
    s
  end.join(" ")
end

node.override['haproxy']['global']['node'] = node['fqdn'] unless node['haproxy']['global']['node']

%w[global defaults].each do |cfg_type|
  template File.join(node['haproxy']['dir'], "#{cfg_type}.cfg") do
    source "key_value.erb"
    variables :data => node['haproxy'][cfg_type]

    owner "root"
    group "root"
    mode "0644"

    extend HAProxy::Helpers
    notifies haproxy_reload_action, haproxy_service_name
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

service_actions = [:enable]
service_actions << :start unless node['haproxy']['delay_start']

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
    action service_actions
  end
when 'runit'
  include_recipe "runit"

  runit_service "haproxy" do
    owner "root"
    group "root"

    default_logger true
    control %w[2 t] # we send USR2 for reload

    action service_actions
    only_if do
      if File.exist?(node['haproxy']['systemd_wrapper_bin'])
        true
      else
        Chef::Log.warn("runit support requires haproxy-systemd-wrapper which is available since HAProxy 1.5-dev18")
        false
      end
    end
  end
end

ruby_block "Schedule delayed HAProxy start" do
  block do
    # NOP NOP NOP
  end
  only_if{ node['haproxy']['delay_start'] }

  extend HAProxy::Helpers
  notifies :start, haproxy_service_name
end
