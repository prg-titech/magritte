module Magritte
  class EnvRef
    attr_accessor :value
    def initialize(value)
      @value = value
    end
  end

  class Env
    class MissingVariable < StandardError
      def initialize(name, env)
        @name = name
        @env = env
      end

      def to_s
        "No such variable: #{@name}"
      end
    end

    class << self
      KEY = :__MAGRITTE_ENV__

      def current
        Thread.current[KEY] ||= new
      end

      def with(bindings={})
        old = self.current
        Thread.current[KEY] = old.with(bindings)
      ensure
        Thread.current[KEY] = old
      end
    end

    attr_reader :own_inputs, :own_outputs
    def initialize(parent=nil, keys={}, inputs=[], outputs=[])
      @parent = parent
      @keys = keys
      @own_inputs = inputs
      @own_outputs = outputs
    end

    def input(n)
      @own_inputs[n] or parent :input, n
    end

    def output(n)
      @own_outputs[n] or parent :output, n
    end

    def each_input
      (0..32).each do |x|
        ch = input(x) or return
        yield ch
      end
    end

    def each_output
      (0..32).each do |x|
        ch = output(x) or return
        yield ch
      end
    end

    def stdin
      input(0)
    end

    def stdout
      output(0)
    end

    def splice(new_parent)
      Env.new(new_parent, @keys.dup, @own_inputs.dup, @own_outputs.dup)
    end

    def slice(keys)
      refs = {}
      keys.each do |key|
        refs[normalize_key(key)] = ref(key)
      end
      Env.new(nil, refs, [], [])
    end

    def self.empty
      new(nil, {}, [], [])
    end

    def self.base
      env = Env.empty
      Builtins.load(env)
    end

    def extend(inputs=[], outputs=[])
      self.class.new(self, {}, inputs, outputs)
    end

    def key?(key)
      ref(key)
      true
    rescue MissingVariable
      false
    end

    def mut(key, val)
      ref(key).value = val
    end

    def let(key, val)
      @keys[normalize_key(key)] = EnvRef.new(val)
      self
    end

    def get(key)
      ref(key).value
    end

    def unhinge!
      @parent = nil
    end

    def repr
      recursive_repr([])
    end

    def inspect
      "#<Env #{repr}>"
    end

  protected
    def own_key?(key)
      @keys.key?(key.to_s)
    end

    def own_ref(key)
      @keys[key]
    end

    def normalize_key(key)
      key.to_s
    end

    def ref(key)
      key = normalize_key(key)

      if own_key?(key)
        @keys[key]
      elsif @parent
        @parent.ref(key)
      else
        missing!(key)
      end
    end

    def missing!(name)
      raise MissingVariable.new(name, self)
    end

  private
    def parent(method, *a, &b)
      @parent && @parent.__send__(method, *a, &b)
    end

    def recursive_repr(visited_envs)
      if visited_envs.include? self
        return "<circular>"
      end
      visited_envs << self

      out = "{"

      env_content = []
      env_content.concat (@keys.map { |key| " #{key.first} = #{key[1].value.repr}" })
      env_content.concat (@own_inputs.map { |input| " < #{input.inspect}" })
      env_content.concat (@own_outputs.map { |output| " > #{output.inspect}" })

      out << env_content.join(";")

      if !@parent.nil?
        out << " + #{@parent.repr}"
      end
      out << " }"
    end
  end
end
