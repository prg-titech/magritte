module Magritte
  class Env
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

    def initialize(parent=nil, keys={}, inputs={}, outputs={}, opts={})
      @parent = parent
      @keys = keys
      @own_inputs = inputs
      @own_outputs = outputs
      @opts = opts
    end

    def input(n)
      @inputs.fetch(n) { @parent.input(n) }
    end

    def output(n)
      @outputs.fetch(n) { @parent.output(n) }
    end

    def stdin
      input(0)
    end

    def stdout
      output(0)
    end

    @empty = new(nil, {}, {}, {}, {})
    def self.empty
      @empty
    end

    def can_mutate_parent?
      @opts[:can_mutate_parent?] || false
    end

    def key?(key)
      own_key?(key.to_s) || (parent && parent.key?(key.to_s))
    end

    def own_key?(key)
      @keys.key?(key.to_s)
    end

    def mut(key, val)
      return @keys[key.to_s] = val if own_key?(key)

      if can_mutate_parent? && parent.key?(key.to_s)
        parent.mut(key, val)
      end

      raise "no key #{key}"
    end

    def with(bindings={})
      new(self, bindings, {})
    end

    def with_mut(bindings={})
      new(self, bindings, can_mutate_parent?: true)
    end
  end
end
