extend HAProxy::ProviderHelpers
include HAProxy::Helpers

action :create do
  template "#{node['haproxy']['dir']}/#{new_resource.template_prefix}.d/#{new_resource.name}.cfg" do
    source new_resource.template || "#{new_resource.template_prefix}_#{new_resource.name}.erb"
    cookbook new_resource.cookbook || cookbook_name # the calling cookbook by default
    variables new_resource.variables

    action :create
    if node['haproxy']['reload_on_update']
      notifies haproxy_reload_action, haproxy_service(new_resource)
    end
  end
end

action :delete do
  file "#{node['haproxy']['dir']}/#{new_resource.template_prefix}.d/#{new_resource.name}.cfg" do
    action :delete
    if node['haproxy']['reload_on_update']
      notifies haproxy_reload_action, haproxy_service(new_resource)
    end
  end
end
