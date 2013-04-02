extend HAProxy::Helpers

action :create do
  listen = template "#{node['haproxy']['dir']}/listen.d/#{new_resource.name}.cfg" do
    source new_resource.template || "listen_#{new_resource.name}.erb"
    cookbook new_resource.cookbook || cookbook_name # the calling cookbook by default
    variables new_resource.variables

    action :nothing
    notifies :start, haproxy_service(new_resource)
    notifies haproxy_reload_action, haproxy_service(new_resource)
  end

  listen.run_action :create
  new_resource.updated_by_last_action(true) if listen.updated_by_last_action?
end

action :delete do
  listen = file "#{node['haproxy']['dir']}/listen.d/#{new_resource.name}.cfg" do
    action :delete
    notifies haproxy_reload_action, haproxy_service(new_resource)
  end

  listen.run_action :delete
  new_resource.updated_by_last_action(true) if listen.updated_by_last_action?

end
