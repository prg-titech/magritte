module Magritte
  module Value

    class Base
      def call(*args)
        raise "Can't call this! (#{self.inspect})"
      end
    end

    class String < Base
      attr_reader :value

      def initialize(value)
        @value = value
      end

      def call(args)
        # Semantics: Look up the thing in current env and call it
        # Proc.current.env
        Proc.current.env.get(@value).call(args)
      end

      def repr
        value
      end
    end

    class Number < Base
      attr_reader :value

      def initialize(value)
        @value = value
      end

      def repr
        value
      end
    end

    class Vector < Base
      attr_reader :elems

      def initialize(elems)
        @elems = elems.freeze
      end

      def call(args)
        head, *rest = (@elems + args)
        head.call(rest)
      end

      def repr
        "[#{elems.map(&:repr).join(" ")}]"
      end
    end

    class Environment < Base
      attr_reader :env

      def initialize(env)
        @env = env
      end

      def repr
        env.inspect
      end
    end

    class Channel < Base
      attr_reader :channel

      def initialize(channel)
        @channel = channel
      end

      def repr
        "<channel:#{channel}>"
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

      def call(args)
        #new_env = Proc.current.env.with(@env)
        raise "TODO"
      end

      def repr
        "<func:#{name}>"
      end
    end

    class BuiltinFunction < Base
      attr_reader :block
      attr_reader :name

      def initialize(name, block)
        @name = name
        @block = block
      end

      def call(args)
        Std.instance_exec(*args, &@block)
      end

      def repr
        "<builtin:#{name}>"
      end
    end
  end
end
