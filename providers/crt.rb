extend HAProxy::ProviderHelpers
include HAProxy::Helpers

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
    if node['haproxy']['reload_on_update']
      notifies :reload, haproxy_service(new_resource)
    end
  end

  new_resource.updated_by_last_action(t.updated_by_last_action?)
end

action :delete do
  f = file new_resource.path do
    action :delete
    if node['haproxy']['reload_on_update']
      notifies :reload, haproxy_service(new_resource)
    end
  end

  new_resource.updated_by_last_action(f.updated_by_last_action?)
end
