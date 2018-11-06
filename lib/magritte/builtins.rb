module Magritte
  module Builtins
    def self.load(env)
      @builtins.each do |(name, func)|
        env.let(name, func)
      end
    end

    @builtins = []

    def self.builtin(name, &impl)
      @builtins << [name, Value::BuiltinFunction.new(name, impl)]
    end

    builtin :put do |val|
      Proc.current.stdout.write(val)
    end

    builtin :get do |val|
      Proc.current.stdin.read
    end
  end
end
