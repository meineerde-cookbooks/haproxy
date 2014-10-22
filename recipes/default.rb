case node['haproxy']['install_method']
when 'source'
  include_recipe "haproxy::source"
when 'package'
  package "haproxy" do
    action :install
    if node['haproxy']['reload_on_update']
      extend HAProxy::Helpers
      notifies :reload, haproxy_service_name
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
    variables :data_path => "haproxy/#{cfg_type}"

    owner "root"
    group "root"
    mode "0644"

    extend HAProxy::Helpers
    notifies :reload, haproxy_service_name
  end
end

template File.join(node['haproxy']['dir'], "peers.cfg") do
  source "peers.erb"
  variables :data_path => 'haproxy/peers'

  owner "root"
  group "root"
  mode "0644"

  extend HAProxy::Helpers
  notifies :reload, haproxy_service_name
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

  extend HAProxy::Helpers
  notifies :reload, haproxy_service_name
end

service_actions = [:enable]
service_actions << :start unless node['haproxy']['delay_start']

def reload_command_with_check(command)
  tmp_config = <<-BASH.gsub(/^\s*/, '').strip
    tmp_config="$(/bin/mktemp)" && \\
    /usr/sbin/haproxy_join #{Shellwords.escape node['haproxy']['dir']} "$tmp_config"
  BASH
  cleanup = "ret=$?; rm -f \"$tmp_config\"; $(exit $ret)"

  "#{tmp_config} && #{command}; #{cleanup}"
end

case node['haproxy']['init_style']
when 'init'
  template "/etc/init.d/haproxy" do
    source "haproxy.init.erb"
    owner "root"
    group "root"
    mode "0755"
  end

  reload = reload_command_with_check("/etc/init.d/haproxy reload")

  service "haproxy" do
    supports :reload => true
    reload_command reload
    action service_actions
  end
when 'runit'
  include_recipe "runit"

  reload = reload_command_with_check("#{node['runit']['sv_bin']} reload #{node['runit']['service_dir']}/haproxy")
  runit_service "haproxy" do
    owner "root"
    group "root"

    default_logger true
    control %w[h]

    reload_command reload

    action service_actions
    only_if do
      installed_version = Mixlib::ShellOut.new(node['haproxy']['bin'], '-v').run_command.tap(&:error!).stdout.lines.first.split(' ')[2]

      if File.exist?(node['haproxy']['systemd_wrapper_bin']) && Gem::Version.new(installed_version) >= Gem::Version.new("1.5.5")
        true
      else
        Chef::Log.warn("runit support requires haproxy-systemd-wrapper which is available since HAProxy 1.5.5")
        false
      end
    end
  end

  # LEGACY: delete old control scripts which where required before HAProxy 1.5.5
  %w[t 2].each do |control_script|
    file "#{node['runit']['service_dir']}/haproxy/control/#{control_script}" do
      action :delete
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
