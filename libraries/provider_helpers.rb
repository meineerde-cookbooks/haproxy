module HAProxy
  module ProviderHelpers
    def self.extended(base)
      if Chef::Version.new(Chef::VERSION).major >= 11
        base.use_inline_resources
      else
        class << base
          alias_method :action_without_notification, :action
          alias_method :action, :notifying_action
        end
      end
    end

    # copied from
    # https://github.com/realityforge/chef-cutlery/blob/2ee0b86a4a54e000735cd0dc211c48f844099615/libraries/notifying_action.rb
    def notifying_action(key, &block)
      action_without_notification key do
        # So that we can refer to these within the sub-run-context block.
        cached_new_resource = new_resource
        cached_current_resource = current_resource

        # Setup a sub-run-context.
        sub_run_context = @run_context.dup
        sub_run_context.resource_collection = Chef::ResourceCollection.new

        # Declare sub-resources within the sub-run-context. Since they are declared here,
        # they do not pollute the parent run-context.
        begin
          original_run_context, @run_context = @run_context, sub_run_context
          instance_eval(&block)
        ensure
          @run_context = original_run_context
        end

        # Converge the sub-run-context inside the provider action.
        # Make sure to mark the resource as updated-by-last-action if any sub-run-context
        # resources were updated (any actual actions taken against the system) during the
        # sub-run-context convergence.
        begin
          Chef::Runner.new(sub_run_context).converge
        ensure
          if sub_run_context.resource_collection.any?(&:updated?)
            new_resource.updated_by_last_action(true)
          end
        end
      end
    end
  end
end
