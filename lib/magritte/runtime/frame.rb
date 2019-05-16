module Magritte
  module Runtime
    class Frame
      attr_reader :env
      def initialize(proc_, env)
        @proc = proc_
        @env = env
      end

      def enter
        @proc.scheduler.register_channels(self)
      end

      def exit
        puts "exit #{repr}"
        @proc.scheduler.unregister_channels(self)
      end

      def repr
        "#frame(#{@proc.pid} #{@env.repr})"
      end

      def inspect
        repr
      end
    end
  end
end
