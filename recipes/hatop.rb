case node["haproxy"]["hatop"]["install_method"]
when "package"
  package "hatop"
when "source"
  include_recipe "python"

  version = node["haproxy"]["hatop"]["version"]
  source_path = "#{Chef::Config[:file_cache_path]}/hatop-#{version}.tar.gz"
  source_url = node["haproxy"]["hatop"]["download_url"] || "http://hatop.googlecode.com/files/hatop-#{version}.tar.gz"

  remote_file source_path do
    source source_url
    checksum node["haproxy"]["hatop"]["checksum"]
    backup false
  end

  directory "/usr/local/share/man/man1" do
    action :create
    recursive true
  end

  bash "install_hatop" do
    cwd Chef::Config[:file_cache_path]
    code <<-EOF
      set -e

      rm -rf hatop-#{version}
      gunzip -c #{Shellwords.escape(source_path)} | tar -x
      cd hatop-#{version}

      install -m 755 bin/hatop /usr/local/bin
      install -m 644 man/hatop.1 /usr/local/share/man/man1
      gzip /usr/local/share/man/man1/hatop.1
    EOF

    action :nothing
    subscribes :run, "remote_file[#{source_path}]"
  end
end
