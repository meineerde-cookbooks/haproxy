extend HAProxy::ProviderHelpers

action :create do
  t = template "#{node['haproxy']['dir']}/#{new_resource.template_prefix}.d/#{new_resource.name}.cfg" do
    source new_resource.template || "#{new_resource.template_prefix}_#{new_resource.name}.erb"
    cookbook new_resource.cookbook || cookbook_name.to_s # the calling cookbook by default
    variables new_resource.variables

    action :create
    if node['haproxy']['reload_on_update']
      notifies :reload, new_resource.resources(:service => 'haproxy')
    end
  end

  new_resource.updated_by_last_action(t.updated_by_last_action?)
end

action :delete do
  f = file "#{node['haproxy']['dir']}/#{new_resource.template_prefix}.d/#{new_resource.name}.cfg" do
    action :delete
    if node['haproxy']['reload_on_update']
      notifies :reload, new_resource.resources(:service => 'haproxy')
    end
  end

  new_resource.updated_by_last_action(f.updated_by_last_action?)
end
