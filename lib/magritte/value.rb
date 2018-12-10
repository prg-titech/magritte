module Magritte
  module Value

    class Base
      def call(*args)
        Proc.current.crash!("Can't call this! (#{self.repr})")
      end
    end

    class String < Base
      attr_reader :value

      def to_s
        @value
      end

      def initialize(value)
        @value = value
      end

      def ==(other)
        other.is_a?(self.class) && other.value = @value
      end

      def call(args)
        # Semantics: Look up the thing in current env and call it
        # Proc.current.env
        Proc.current.env.get(@value).call(args)
      rescue Env::MissingVariable => e
        Proc.current.crash!(e.to_s)
      end

      def repr
        if @value =~ /[\r\n\\]/
          @value.inspect
        else
          value
        end
      end
    end

    class Number < Base
      attr_reader :value

      def initialize(value)
        @value = value
      end

      def repr
        value.to_s.gsub(/\.0$/, '')
      end

      def to_s
        repr
      end
    end

    class Vector < Base
      attr_reader :elems

      def initialize(elems)
        @elems = elems.freeze
      end

      def call(args)
        head, *rest = (@elems + args)
        Proc.current.crash!("Empty call") if head.nil?
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
        env.repr
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
      attr_reader :bindnames
      attr_reader :expr

      def initialize(name, env, bindnames, expr)
        @name = name
        @env = env
        @bindnames = bindnames
        @expr = expr
      end

      def call(args)
        env = @env.splice(Proc.current.env)
        if args.size < bindnames.size
          Proc.current.crash!("#{repr}: not enough arguments: #{args.size} < #{bindnames.size}")
        end

        if args.size > bindnames.size
          Proc.current.crash!("#{repr}: too many arguments: #{args.size} > #{bindnames.size}")
        end
        args.zip(bindnames) do |arg, bind|
          env.let(bind, arg)
        end
        Proc.enter_frame(env) { Interpret.interpret(@expr[0]) }
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
        Std.instance_exec(*args, &@block) || Status.normal
      rescue Builtins::ArgError => e
        Proc.current.crash!(e.to_s)
      end

      def repr
        "<builtin:#{name}>"
      end
    end

    class Compensation < Base
      attr_reader :action
      attr_reader :uncond

      def initialize(action, uncond)
        @action = action
        @uncond = uncond
      end

      def run
        @action.call([])
      end

      def run_checkpoint
        run if @uncond == :unconditional
      end
    end
  end
end
