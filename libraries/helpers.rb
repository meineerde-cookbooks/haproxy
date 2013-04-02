module HAProxy
  module Helpers
    def haproxy_service_name
      case node['haproxy']['init_style']
        when "init" then "service[haproxy]"
        when "runit" then "runit_service[haproxy]"
      end
    end

    def haproxy_service(collection=self)
      case node['haproxy']['init_style']
        when "init" then collection.resources(:service => "haproxy")
        when "runit" then collection.resources(:runit_service => "haproxy")
      end
    end

    def haproxy_reload_action
      case node['haproxy']['init_style']
        when "init" then :reload
        when "runit" then :usr2
      end
    end
  end
end
