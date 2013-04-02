extend HAProxy::Helpers

action :create do
  backend = template "#{node['haproxy']['dir']}/#{new_resource.template_prefix}.d/#{new_resource.name}.cfg" do
    source new_resource.template || "#{new_resource.template_prefix}_#{new_resource.name}.erb"
    cookbook new_resource.cookbook || cookbook_name # the calling cookbook by default
    variables new_resource.variables

    action :nothing
    notifies :start, haproxy_service(new_resource)
    notifies haproxy_reload_action, haproxy_service(new_resource)
  end

  backend.run_action :create
  new_resource.updated_by_last_action(true) if backend.updated_by_last_action?
end

action :delete do
  backend = file "#{node['haproxy']['dir']}/#{new_resource.template_prefix}.d/#{new_resource.name}.cfg" do
    action :nothing
    notifies haproxy_reload_action, haproxy_service(new_resource)
  end

  backend.run_action :delete
  new_resource.updated_by_last_action(true) if backend.updated_by_last_action?
end
