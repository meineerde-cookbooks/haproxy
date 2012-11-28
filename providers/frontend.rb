action :create do
  haproxy = new_resource.resources(:service => "haproxy")

  template "#{node['haproxy']['dir']}/frontend.d/#{new_resource.name}.cfg" do
    source new_resource.template || "frontend_#{new_resource.name}.erb"
    cookbook new_resource.cookbook || cookbook_name # the calling cookbook by default
    variables new_resource.variables

    action :create
    notifies :start, haproxy
    notifies :reload, haproxy
  end
end

action :delete do
  haproxy = new_resource.resources(:service => "haproxy")

  file "#{node['haproxy']['dir']}/frontend.d/#{new_resource.name}.cfg" do
    action :delete
    notifies :reload, haproxy
  end
end
