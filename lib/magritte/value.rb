module Magritte
  module Value

    class Base
      def call(*args)
        raise "Can't call this!"
      end
    end

    class String < Base
      attr_reader :value

      def initialize(value)
        @value = value
      end

      def call(*args)
        # Semantics: Look up the thing in current env and call it
        # Proc.current.env
        raise "TODO"
      end
    end

    class Number < Base
      attr_reader :value

      def initialize(value)
        @value = value
      end
    end

    class Vector < Base
      attr_reader :elems

      def initialize(elems)
        @elems = elems.freeze
      end

      def call(*args)
        head, *rest = @elems
        head.call(*rest, *args)
      end
    end

    class Environment < Base
      attr_reader :env

      def initialize(env)
        @env = env
      end
    end

    class Channel < Base
      attr_reader :channel

      def initialize(channel)
        @channel = channel
      end
    end

    class Function < Base
      attr_reader :name
      attr_reader :env
      attr_reader :bindname
      attr_reader :expr

      def initialize(name, env, bindname, expr)
        @name = name
        @env = env
        @bindname = bindname
        @expr = expr
      end

      def call(*args)
        #new_env = Proc.current.env.with(@env)
        raise "TODO"
      end
    end

    class BuiltinFunction < Base
      attr_reader :block

      def initialize(block)
        @block = block
      end

      def call(*args)
        @block.call(*args)
      end
    end
  end
end
