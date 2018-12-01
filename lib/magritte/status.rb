module Magritte
  class Status

    def initialize(properties, msg = nil)
      @properties = properties
      @msg = msg
    end

    def property?(name)
      @properties.include?(name.to_sym)
    end

    def self.[](*args, msg: nil)
      new(Set.new(args), msg)
    end

    def self.normal
      new(Set.new)
    end

    def normal?
      @properties.empty?
    end

    def fail?
      property?(:fail) || property?(:crash)
    end

    def repr
      out = ""
      out << "!" if fail?
      out << "[" << @properties.to_a.join(" ") << "]"
      out << ":" << @msg if @msg
      out
    end
  end
end
