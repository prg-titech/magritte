module Magritte
  module Builtins
    def self.load(env)
      @builtins.each do |(name, func)|
        env.let(name, func)
      end
      env
    end

    @builtins = []

    def self.builtin(name, arg_types, rest_type = nil, &impl)
      checked_impl = proc do |*a|
        if rest_type.nil? && a.size != arg_types.size
          raise "Argument error: #{name} expects #{arg_types.size} arguments. Got: #{a.size}"
        end
        named_args = a.first(arg_types.size)
        rest_args = a.last(a.size - arg_types.size)
        named_args.zip(arg_types) do |value, type|
          next if type == :any
          raise "Arg type raise" unless value.is_a?(Value.const_get(type))
        end
        if rest_type
          rest_args.each do |arg|
            next if type == :any
            raise "Rest arg type raise" unless arg.is_a?(Value.const_get(rest_type))
          end
        end
        impl.call(*a)
      end
      @builtins << [name, Value::BuiltinFunction.new(name, impl)]
    end

    builtin :put, [], :any  do |*vals|
      vals.each { |val| put(val) }
    end

    builtin :get, [] do
      put(get)
    end

    builtin :make_channel, [] do
      put Channel.new
    end

    builtin :for, [:Vector] do |vec|
      error!("Not a vector") unless vec.is_a?(Value::Vector)
      vec.elems.each { |val| put(val) }
    end

    builtin :take, [:Number] do |n|
      take(n.value.to_i)
    end

    builtin :drain, [] do
      loop { put get }
    end
  end
end
