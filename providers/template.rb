extend HAProxy::ProviderHelpers

use_inline_resources

action :create do
  template "#{node['haproxy']['dir']}/#{new_resource.template_prefix}.d/#{new_resource.name}.cfg" do
    source new_resource.template || "#{new_resource.template_prefix}_#{new_resource.name}.erb"
    cookbook new_resource.cookbook || cookbook_name.to_s # the calling cookbook by default
    variables new_resource.variables

    action :create
  end
end

action :delete do
  file "#{node['haproxy']['dir']}/#{new_resource.template_prefix}.d/#{new_resource.name}.cfg" do
    action :delete
  end
end
