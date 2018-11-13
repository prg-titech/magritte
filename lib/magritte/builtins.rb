module Magritte
  module Builtins

    class ArgError < RuntimeError
    end

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
          raise ArgError.new("#{name} expects #{arg_types.size} arguments. Got: #{a.size}")
        end
        named_args = a.first(arg_types.size)
        rest_args = a.last(a.size - arg_types.size)
        named_args.zip(arg_types) do |value, type|
          next if type == :any
          raise ArgError.new("Arg type raise") unless value.is_a?(Value.const_get(type))
        end
        if rest_type
          rest_args.each do |arg|
            next if type == :any
            raise ArgError.new("Rest arg type raise") unless arg.is_a?(Value.const_get(rest_type))
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

    builtin :sleep, [:Number] do |n|
      sleep(n.value.to_f)
    end

    builtin :'count-forever', [] do |n|
      i = 0
      loop { put Value::Number.new(i); i += 1 }
    end

    builtin :list, [], :any do |*a|
      put Value::Vector.new(a)
    end

    builtin :fan, [:Number, :any], :any do |times, fn, *a|
      times.value.to_i.times do
        Spawn.s_ { loop { fn.call([get] + a) } }.go
      end
    end

    builtin :add, [], :Number do |*nums|
      put Value::Number.new(nums.map { |x| x.value.to_i }.inject(0, &:+))
    end

    builtin :exec, [], :any do |*a|
      Value::Vector.new([]).call(a)
    end
  end
end
