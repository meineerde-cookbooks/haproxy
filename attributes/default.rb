default['haproxy']['dir'] = "/etc/haproxy"
default['haproxy']['ssl_dir'] = "/etc/haproxy/ssl"

default['haproxy']['install_method'] = "package"
default['haproxy']['init_style'] = "init"
default['haproxy']['extra_opts'] = []

# You can set any additional valid values for global and default values in Roles
# You can disable any settings by setting it to nil
default['haproxy']['global']['chroot'] = "/var/lib/haproxy"
default['haproxy']['global']['daemon'] = nil # if nil, this is set depending on the init style and nbproc
default['haproxy']['global']['description'] = nil
default['haproxy']['global']['group'] = "haproxy"
default['haproxy']['global']['log'] = "127.0.0.1 local0 debug"
default['haproxy']['global']['log-send-hostname'] = nil
default['haproxy']['global']['log-tag'] = nil
default['haproxy']['global']['nbproc'] = 1
default['haproxy']['global']['node'] = nil # the hostname by default
default['haproxy']['global']['pidfile'] = "/var/run/haproxy.pid"
default['haproxy']['global']['stats socket']['path'] = "/var/lib/haproxy/stats.socket"
default['haproxy']['global']['stats socket']['user'] = nil # uses the HAProxy user by default
default['haproxy']['global']['stats socket']['group'] = nil # uses the HAProxy group by default
default['haproxy']['global']['stats socket']['mode'] = "0640"
default['haproxy']['global']['stats socket']['level'] = "operator"
default['haproxy']['global']['stats timeout'] = "10s"
default['haproxy']['global']['stats maxconn'] = "10"
default['haproxy']['global']['user'] = "haproxy"

default['haproxy']['global']['maxconn'] = 10240
default['haproxy']['global']['maxpipes'] = nil # by default maxconn/4

# You probably want to adapt these values to your needs!
# You can add any additional valid default values here.
default['haproxy']['defaults']['timeout check'] = nil # Use the default settings based on inter
default['haproxy']['defaults']['timeout client'] = "5s" # Should be equal to timeout server
default['haproxy']['defaults']['timeout connect'] = "5s" # How long to wait for the connection to the backend server to be established
default['haproxy']['defaults']['timeout http-keep-alive'] = "500ms" # Don't wait long for additional keep alive requests
default['haproxy']['defaults']['timeout http-request'] = "5s" # How long to wait for the client to send its full header
default['haproxy']['defaults']['timeout queue'] = "10s" # How long to put requests into a queue
default['haproxy']['defaults']['timeout server'] = "5s" # How long to wait for the server to start responding
default['haproxy']['defaults']['timeout tarpit'] = nil # by default the same as timeout connect
