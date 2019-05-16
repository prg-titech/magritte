module Magritte
  module Builtins

    class ArgError < RuntimeError
    end

    def self.load(env)
      @builtins.each do |(name, func)|
        env.let(name, func)
      end

      env.let('__repr__', '<builtins>')

      load_file("#{ROOT_DIR}/mag/prelude.mag", env)
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
        call(impl, *a)
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

    builtin :type, [:any] do |val|
      put Value::String.new(val.typename)
    end

    builtin :vtype, [:String] do |val|
      typename = begin
         Proc.current.env.get(val.value).typename
      rescue Env::MissingVariable
        'undef'
      end

      put Value::String.new(typename)
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
      consume { put get }
    end

    builtin :sleep, [:Number] do |n|
      sleep(n.value.to_f)
      Status.normal
    end

    builtin :'count-forever', [] do |n|
      i = 0
      produce { put Value::Number.new(i); i += 1 }
    end

    builtin :list, [], :any do |*a|
      put Value::Vector.new(a)
      Status.normal
    end

    builtin :'loop-channel', [:Channel, :any], :any do |c, h, *a|
      channel = c.channel

      loop_channel(c.channel) { call(h, a) }
    end

    builtin :stdin, [] do
      put Value::Channel.new(Proc.current.stdin)
    end

    builtin :stdout, [] do
      put Value::Channel.new(Proc.current.stdout)
    end

    builtin :add, [], :Number do |*nums|
      put Value::Number.new(nums.map { |x| x.value.to_f }.inject(0, &:+))
      Status.normal
    end

    builtin :sub, [:Number, :Number] do |decremand, num|
      put Value::Number.new(num.value.to_f - decremand.value.to_f)
      Status.normal
    end

    builtin :mul, [], :Number do |*nums|
      put Value::Number.new(nums.map { |x| x.value.to_f }.inject(1, &:*))
      Status.normal
    end

    builtin :mod, [:Number, :Number] do |base, n|
      put Value::Number.new(n.value % base.value)
      Status.normal
    end

    builtin :pow, [:Number, :Number] do |exponent, base|
      put Value::Number.new(base.value.to_f ** exponent.value.to_f)
      Status.normal
    end

    builtin :round, [:Number, :Number] do |decimal_precision, n|
      put Value::Number.new(n.value.round(decimal_precision.value))
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
        call h, a
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

    builtin :rand, [] do
      put Value::Number.new(rand)
    end

    builtin :eq, [:any, :any] do |lhs, rhs|
      bool(lhs.class == rhs.class && lhs == rhs)
    end

    builtin :any, [:any] do |predicate|
      result = false
      consume do
        elem = get
        status = call(predicate, [elem])
        (result = true; break) unless status.fail?
      end
      bool(result)
    end

    builtin :gt, [:Number, :Number] do |than, is|
      bool(is.value.to_f > than.value.to_f)
    end

    builtin :lt, [:Number, :Number] do |than, is|
      bool(is.value.to_f < than.value.to_f)
    end

    builtin :div, [:Number, :Number] do |den, num|
      put Value::Number.new(num.value.to_f / den.value.to_f)
    end

    builtin :filter, [:any], :any do |h, *a|
      consume do
        val = get
        put val unless call(h, a + [val]).fail?
      end
    end

    builtin :size, [:any] do |e|
      s = case e
      when Value::String
        e.value.size
      when Value::Vector
        e.elems.size
      when Value::Environment
        e.env.size
      else
        Proc.current.crash!("size: don't know how to size #{e.repr}")
      end

      put Value::Number.new(s)
    end

    builtin :str, [], :any do |*a|
      put Value::String.new(a.map(&:to_s).join)
    end

    builtin :append, [:String, :String] do |string_to_append, string|
      put Value::String.new(string.value + string_to_append.value)
    end

    builtin :'string-to-number', [:String], :Number do |string, base = Value::Number.new(10)|
      put Value::Number.new(string.value.to_i(base.value))
    end

    builtin :contains, [:any, :any] do |e, container|
      case container
      when Value::Vector
        bool(container.elems.any? { |el| el == e })
      when Value::String
        bool(container.value[e.to_s])
      else
        bool(false)
      end
    end

    # the null channel
    builtin :'make-null', [] do
      put Value::Channel.new(Null.new)
    end

    builtin :trace, [] do
      Proc.current.trace.reverse_each.drop(1).each do |tracepoint|
        location = Value::String.new(tracepoint.range.repr)
        put Value::Vector.new([tracepoint.callable, location])
      end

      Status.normal
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
