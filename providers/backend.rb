extend HAProxy::Helpers

action :create do
  template "#{node['haproxy']['dir']}/backend.d/#{new_resource.name}.cfg" do
    source new_resource.template || "backend_#{new_resource.name}.erb"
    cookbook new_resource.cookbook || cookbook_name # the calling cookbook by default
    variables new_resource.variables

    action :create
    notifies :start, haproxy_service(new_resource)
    notifies haproxy_reload_action, haproxy_service(new_resource)
  end
end

action :delete do
  file "#{node['haproxy']['dir']}/backend.d/#{new_resource.name}.cfg" do
    action :delete
    notifies haproxy_reload_action, haproxy_service(new_resource)
  end
end
