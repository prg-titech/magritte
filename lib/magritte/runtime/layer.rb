module Magritte
  module Runtime
    class Layer
      class Inst
        attr_reader :name, :args
        def initialize(name, args)
          @name = name
          @args = args
        end

        def repr
          out = "@!#{name}"
          out << " #{args.map(&method(:repr_of)).join(' ')}" if args.any?
          out
        end

        def repr_of(e)
          case e
          when Tree::Node
            e.repr(1)
          when Value::Base, Channel
            e.repr
          when Lexer::Range
            e.repr
          else
            e.inspect
          end
        end

        def inspect
          repr
        end
      end

      class DSL < BasicObject
        def self.gen(&b)
          new._gen(&b)
        end

        def initialize
          @out = []
        end

        def _gen(&b)
          yield self
          @out
        end

        def method_missing(name, *args)
          @out << Inst.new(name, args)
        end
      end

      def self.gen(trace, &b)
        new(trace, DSL.gen(&b), 0)
      end

      attr_reader :trace, :values
      attr_accessor :frame
      def initialize(trace, instructions, index)
        @trace = trace
        @instructions = instructions
        @index = index
        @values = []
        @frame = nil
      end

      def merge_frame(frame)
        return false if @frame
        @frame = frame
      end

      def pop_values
        v, @values = @values, []
        v
      end

      def shift
        @values.shift
      end

      def repr
        range = (@index..@index+2)
        reprs = @instructions[range].map(&:repr).join('; ')
        reprs << '; ...' if @instructions.size >= @index + 2

        reprs = '... ' + reprs if @index > 0

        out = "[#{reprs}](#{values.map(&:repr).join(' ')})"
        out << "*#{@frame.env.repr}" if @frame
        out
      end

      def done?
        @index >= @instructions.size
      end

      def push(*values)
        @values.concat(values)
      end

      alias << push

      def step
        out = @instructions[@index]
        @index += 1
        out
      end
    end
  end
end
