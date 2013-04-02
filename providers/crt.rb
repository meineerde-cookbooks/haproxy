extend HAProxy::Helpers

action :create do
  files = [
    new_resource.key,
    new_resource.certificate,
    new_resource.intermediate
  ].flatten.compact

  template new_resource.path do
    source "concat_files.erb"
    cookbook "haproxy"

    owner new_resource.owner
    group new_resource.group
    mode new_resource.mode

    variables :files => files
    action :create

    notifies haproxy_reload_action, haproxy_service(new_resource)
  end
end

action :delete do
  file new_resource.path do
    action :delete
    notifies haproxy_reload_action, haproxy_service(new_resource)
  end
end
