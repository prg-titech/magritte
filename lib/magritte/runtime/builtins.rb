module Magritte
  module Runtime
    class Builtin
      @@registry = {}

      def self.builtin(name, spec, rest_spec=nil, &b)
        @@registry[name] = new(name, spec, rest_spec, &b)
      end

      def self.get(name)
        @@registry.fetch(name) { raise "no builtin `#{name}`" }
      end

      attr_reader :name, :impl
      def initialize(name, spec, rest_spec, &impl)
        @name = name
        @spec = spec.freeze
        @rest_spec = rest_spec
        @impl = impl
      end

      def repr
        "#builtin.#{name}"
      end

      class Mismatch < StandardError; end

      def run(proc_, a)
        match!(a)
        proc_.layer self do |inst|
          instance_exec(inst, *a, &@impl)
        end
      rescue Mismatch
        proc_.crash("argument mismatch")
      end

      def crash!(m)
        raise Mismatch.new(m)
      end

      def match!(args)
        args, rest = args.take(@spec.size), args.drop(@spec.size)
        if args.size < @spec.size || (@rest_spec.nil? && rest.any?)
          crash!("argument mismatch")
        end

        @spec.zip(args) do |s, a|
          match_one!(s, a)
        end

        rest.each do |a|
          match_one!(@rest_spec, a)
        end
      end

      def match_one!(spec, a)
        crash!("mismatch #{spec}, #{a.repr}") unless match_one?(spec, a)
      end

      def match_one?(spec, a)
        case spec
        when :any then true
        when Symbol then a.is_a?(Value.const_get(spec))
        end
      end

      builtin :put, [], :any do |inst, *a|
        a.each { |e| inst.push e }
        inst.write
      end

      builtin :for, [], :Vector do |inst, *a|
        a.each { |e| inst.push e }
        inst.expand
        inst.write
      end

      builtin :add, [], :Number do |inst, *a|
        inst.push Value::Number.new(a.map(&:value).inject(0, &:+))
        inst.write
      end

      builtin :get, [] do |inst|
        inst.read
        inst.write
      end
    end
  end
end
