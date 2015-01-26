extend HAProxy::ProviderHelpers

use_inline_resources

action :create do
  files = [
    new_resource.key,
    new_resource.certificate,
    new_resource.intermediate
  ].flatten.compact

  t = template new_resource.path do
    source "concat_files.erb"
    cookbook "haproxy"

    owner new_resource.owner
    group new_resource.group
    mode new_resource.mode

    variables :files => files

    action :create
  end
end

action :delete do
  file new_resource.path do
    action :delete
    if node['haproxy']['reload_on_update']
      notifies :reload, new_resource.resources(:service => 'haproxy')
    end
  end
end
