actions :create, :delete
default_action :create

attribute :name, :kind_of => String, :name_attribute => true, :required => true
attribute :variables, :kind_of => Hash, :default => {}

attribute :template, :kind_of => String
attribute :cookbook, :kind_of => String
