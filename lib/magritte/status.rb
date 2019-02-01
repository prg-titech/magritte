module Magritte
  module Reason
    class Base
      def to_s
        raise 'abstract'
      end
    end

    class Crash < Base
      attr_reader :msg
      def initialize(msg)
        @msg = msg
      end

      def to_s
        msg
      end
    end

    class Close < Base
      attr_reader :channel
      def initialize(channel)
        @channel = channel
      end

      def to_s
        "channel closed: #{@channel.inspect}"
      end
    end

    class Bug < Base
      attr_reader :exception
      def initialize(exception)
        @exception = exception
      end

      def to_s
        "internal bug: #{@exception.to_s}"
      end
    end

    class Compile < Bug
      def to_s
        "compile error: #{@exception.class.name}\n#{@exception.to_s}"
      end
    end

    class UserInterrupt < Bug
      def to_s
        "user interrupt (^C)"
      end
    end

  end

  class Status
    attr_reader :reason
    def initialize(properties, reason = nil)
      @properties = properties
      @reason = reason
    end

    def property?(name)
      @properties.include?(name.to_sym)
    end

    def self.[](*args, reason: nil)
      new(Set.new(args), reason)
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

    def crash?
      property?(:crash)
    end

    def inspect
      "#<Status #{repr}>"
    end

    def repr
      out = ""
      out << "!" if fail?
      out << "[" << @properties.to_a.join(" ") << "]" if @properties.any?
      out << ":" << @reason.to_s if @reason
      out << "(normal)" if out.empty?
      out
    end
  end
end
