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
  end
end
