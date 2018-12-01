module Magritte
  module Builtins

    class ArgError < RuntimeError
    end

    def self.load(env)
      @builtins.each do |(name, func)|
        env.let(name, func)
      end
      load_file("#{ROOT_DIR}/mash/prelude.mash", env)
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
      Status.normal
    end

    builtin :get, [] do
      put(get)
      Status.normal
    end

    builtin :'make-channel', [] do
      put Value::Channel.new(Channel.new)
      Status.normal
    end

    builtin :for, [:Vector] do |vec|
      vec.elems.each { |val| put(val) }
      Status.normal
    end

    builtin :take, [:Number] do |n|
      take(n.value.to_i)
      Status.normal
    end

    builtin :debug, [] do
      require 'pry'
      binding.pry
    end

    builtin :drain, [] do
      loop { put get }
    end

    builtin :sleep, [:Number] do |n|
      sleep(n.value.to_f)
      Status.normal
    end

    builtin :'count-forever', [] do |n|
      i = 0
      loop { put Value::Number.new(i); i += 1 }
    end

    builtin :list, [], :any do |*a|
      put Value::Vector.new(a)
      Status.normal
    end

    builtin :each, [:any], :any do |h, *a|
      loop { h.call(a + [get]) }
    end

    builtin :fan, [:Number, :any], :any do |times, fn, *a|
      times.value.to_i.times do
        Spawn.s_ { loop { fn.call(a + [get]) } }.go
      end
      Status.normal
    end

    builtin :add, [], :Number do |*nums|
      put Value::Number.new(nums.map { |x| x.value.to_i }.inject(0, &:+))
      Status.normal
    end

    builtin :exec, [], :any do |*a|
      Value::Vector.new([]).call(a)
      Status.normal
    end

    builtin :'file-lines', [:String] do |fname|
      File.foreach(fname.value) do |line|
        put(Value::String.new(line))
      end
      Status.normal
    end

    builtin :local, [] do
      put(Value::Environment.new(Proc.current.env))
      Status.normal
    end

    builtin :true, [] do
      Status.normal
    end

    builtin :false, [] do
      Status[:fail]
    end

    builtin :crash, [], :String do |*a|
      Proc.current.crash!(a.map(&:value).join(" "))
    end

    builtin :try, [:any], :any do |h, *a|
      begin
        h.call(a)
      rescue Proc::Interrupt => e
        e.status
      end
    end

    builtin :return, [] do
      Proc.current.interrupt!(Status.normal)
    end

    builtin :fail, [] do
      Proc.current.interrupt!(Status[:fail])
    end

    # Initialize environment with functions that can be defined in the language itself
    def self.load_lib(lib_name, source, env)
      # Transform the lib string into an ast
      ast = Parser.parse(Skeleton.parse(Lexer.new(lib_name, source)))
      c = Collector.new
      env.own_outputs[0] = c
      # Evaluate the ast, which will add the lib functions to the env
      Proc.spawn(Code.new { Interpret.interpret(ast) }, env).start
      c.wait_for_close
      env
    end

    def self.load_file(file_path, env)
      load_lib(file_path, File.read(file_path), env)
    end
  end
end
