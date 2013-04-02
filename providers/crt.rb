extend HAProxy::Helpers

action :create do
  files = [
    new_resource.key,
    new_resource.certificate,
    new_resource.intermediate
  ].flatten.compact

  crt = template(new_resource.path) do
    source "concat_files.erb"
    cookbook "haproxy"

    owner new_resource.owner
    group new_resource.group
    mode new_resource.mode

    variables :files => files

    action :nothing
    notifies haproxy_reload_action, haproxy_service(new_resource)
  end

  crt.run_action :create
  new_resource.updated_by_last_action(true) if crt.updated_by_last_action?
end

action :delete do
  crt = file(new_resource.path) do
    action :nothing
    notifies haproxy_reload_action, haproxy_service(new_resource)
  end

  crt.run_action :delete
  new_resource.updated_by_last_action(true) if crt.updated_by_last_action?
end
