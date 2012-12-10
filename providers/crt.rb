action :create do
  files = [
    new_resource.key,
    new_resource.certificate,
    new_resource.intermediate
  ].flatten.compact

  haproxy = new_resource.resources(:service => "haproxy")
  template new_resource.path do
    source "concat_files.erb"
    cookbook "haproxy"

    owner new_resource.owner
    group new_resource.group
    mode new_resource.mode

    variables :files => files
    action :create

    notifies :reload, haproxy
  end
end

action :delete do
  haproxy = new_resource.resources(:service => "haproxy")

  file new_resource.path do
    action :delete
    notifies :reload, haproxy
  end
end
