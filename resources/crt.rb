actions :create, :delete
default_action :create

attribute :path, :kind_of => String, :name_attribute => true

attribute :key, :kind_of => String
attribute :certificate, :kind_of => String
attribute :intermediate, :kind_of => [ String, Array ]

attribute :owner, :kind_of => String, :default => "root"
attribute :group, :kind_of => String, :default => "root"
attribute :mode, :kind_of => [ String, Integer ], :default => "0600"
