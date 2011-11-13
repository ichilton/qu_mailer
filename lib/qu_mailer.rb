module Qu
  module Mailer
    class << self
      attr_accessor :default_queue_target, :default_queue_name
      attr_reader :excluded_environments

      def excluded_environments=(envs)
        @excluded_environments = [*envs].map(&:to_sym)
      end

      def included(base)
        base.extend(ClassMethods)
      end
    end

    self.default_queue_target = ::Qu
    self.default_queue_name = 'mailer'
    self.excluded_environments = [:test]

    module ClassMethods
      def current_env
        ::Rails.env
      end

      def method_missing(method_name, *args)
        return super if environment_excluded?

        if action_methods.include?(method_name.to_s)
          MessageDecoy.new(self, method_name, *args)
        else
          super
        end
      end

      def perform(action, *args)
        self.send(:new, action, *args).message.deliver
      end

      def environment_excluded?
        !ActionMailer::Base.perform_deliveries || excluded_environment?(current_env)
      end

      def excluded_environment?(name)
        ::Qu::Mailer.excluded_environments && ::Qu::Mailer.excluded_environments.include?(name.to_sym)
      end

      def qu
        ::Qu::Mailer.default_queue_target
      end

      def queue
        ::Qu::Mailer.default_queue_name
      end

      class MessageDecoy
        def initialize(mailer_class, method_name, *args)
          @mailer_class = mailer_class
          @method_name = method_name
          *@args = *args
        end

        def qu
          ::Qu::Mailer.default_queue_target
        end

        def actual_message
          @actual_message ||= @mailer_class.send(:new, @method_name, *@args).message
        end

        def deliver
          qu.enqueue(@mailer_class, @method_name, *@args)
        end
    
        def deliver!
          actual_message.deliver!
        end

        def method_missing(method_name, *args)
          actual_message.send(method_name, *args)
        end
      end
    end
  end
end
