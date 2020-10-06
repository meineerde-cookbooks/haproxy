actions :create, :delete
default_action :create

attr_reader :template_prefix
def initialize(*args)
  super
  @template_prefix = "peers"
  @provider = Chef::Provider::HaproxyTemplate
end

attribute :name, :kind_of => String, :name_attribute => true, :required => true
attribute :variables, :kind_of => Hash, :default => {}

attribute :template, :kind_of => String
attribute :cookbook, :kind_of => String
