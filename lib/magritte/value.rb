module Magritte
  module Value

    class Base
      def call(args, range)
        Proc.current.crash!("Can't call this! (#{self.repr}) (at #{range.repr})")
      end

      def typename
        raise 'abstract'
      end
    end

    class String < Base
      attr_reader :value

      def to_s
        @value
      end

      def typename
        'string'
      end

      def initialize(value)
        @value = value
      end

      def ==(other)
        other.is_a?(self.class) && other.value == @value
      end

      def call(args, range)
        # Semantics: Look up the thing in current env and call it
        # Proc.current.env
        Proc.current.env.get(@value).call(args, range)
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
        @value = value.to_f
      end

      def typename
        'number'
      end

      def repr
        value.to_s.gsub(/\.0$/, '')
      end

      def to_s
        repr
      end

      def ==(other)
        other.is_a?(self.class) && other.value == @value
      end
    end

    class Vector < Base
      attr_reader :elems

      def initialize(elems)
        @elems = elems.freeze
      end

      def typename
        'vector'
      end

      def call(args, range)
        head, *rest = (@elems + args)
        Proc.current.crash!("Empty call") if head.nil?
        head.call(rest, range)
      end

      def repr
        "[#{elems.map(&:repr).join(" ")}]"
      end

      def to_s
        repr
      end

      def ==(other)
        other.is_a?(self.class) && other.elems.size == @elems.size &&
          other.elems.zip(@elems).map { |le, re| le == re }.all?
      end
    end

    class Environment < Base
      attr_reader :env

      def typename
        'env'
      end

      def initialize(env)
        @env = env
      end

      def repr
        env.repr
      end

      def to_s
        repr
      end
    end

    class Channel < Base
      attr_reader :channel

      def initialize(channel)
        @channel = channel
      end

      def typename
        'channel'
      end

      def repr
        "<channel:#{channel}>"
      end

      def to_s
        repr
      end

      def ==(other)
        other.is_a?(self.class) && other.channel == @channel
      end
    end

    class Function < Base
      attr_reader :name
      attr_reader :env
      attr_reader :patterns
      attr_reader :expr

      def initialize(name, env, patterns, expr)
        @name = name
        @env = env
        @patterns = patterns
        @expr = expr

        if @patterns.size != @expr.size
          raise "malformed function (#{@patterns.size} patterns, #{@expr.size} bodies"
        end
      end

      def typename
        'function'
      end

      def call(args, range)
        env = @env.splice(Proc.current.env)
        bound, match_index = match(args, env)
        Proc.current.with_trace(self, range) do
          Proc.enter_frame(bound) { Interpret.interpret(@expr[match_index]) }
        end
      end

      def match(args, env)
        args = Vector.new(args)
        @patterns.each_with_index do |pat, i|
          bound = Pattern.evaluate(pat, args, env)
          return [bound, i] if bound
        end
        Proc.current.crash!("Pattern match failed on #{self.repr} for #{args.repr}")
      end

      def repr
        "<func:#{name}>"
      end

      def to_s
        repr
      end
    end

    class BuiltinFunction < Base
      attr_reader :block
      attr_reader :name

      def initialize(name, block)
        @name = name
        @block = block
      end

      def typename
        'builtin'
      end

      def call(args, range)
        Proc.current.with_trace(self, range) do
          Std.instance_exec(*args, &@block) || Status.normal
        end
      rescue Builtins::ArgError => e
        Proc.current.crash!(e.to_s)
      end

      def repr
        "<builtin:#{name}>"
      end

      def to_s
        repr
      end
    end

    class Compensation < Base
      attr_reader :action
      attr_reader :range
      attr_reader :uncond

      def initialize(action, range, uncond)
        @action = action
        @range = range
        @uncond = uncond
      end

      def typename
        'compensation'
      end

      def repr
        "<compensation#{@uncond ? '!' : ''}:#{@range.repr}>"
      end

      def run
        @action.call([], @range)
      end

      def run_checkpoint
        run if @uncond == :unconditional
      end
    end
  end
end
