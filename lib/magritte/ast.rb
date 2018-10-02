puts "here"
module Magritte
  module AST
    class Attr
      attr_reader :value
      def initialize(value)
        @value = value
      end
      def each(&block)
        raise "abstract"
      end

      def map(&block)
        raise "abstract"
      end
    end
    
    class DataAttr < Attr
      def each(&block)
        #pass
      end

      def map(&block)
        self
      end
    end

    class RecAttr < Attr
      def each(&block)
        block.call(@value)
      end

      def map(&block)
        RecAttr.new(block.call(@value))
      end
    end

    class ListRecAttr < Attr
      def each(&block)
        @value.each(&block)
      end

      def map(&block)
        ListRecAttr.new(@value.map(&block))
      end
    end
  
    class Node
      class << self
        def attrs
          @attrs ||= []
        end

        def types
          @types ||= []
        end

        def defattr(name, type)
          attrs << name
          types << type
          index = attrs.size - 1
          define_method name do
            attrs[index].value
          end
        end

        def make(*attrs)
          new(attrs.zip(types).map { |(value, type)| type.new(value) })
        end

        alias [] make
      end

      attr_reader :attrs
      def initialize(attrs)
        @attrs = attrs
      end

      def each(&block)
        @attrs.each do |attr|
          attr.each(&block)
        end
      end

      def map(&block)
        self.class.new(@attrs.map { |attr| attr.map(&block) })
      end
    end

    class Variable < Node
      defattr :name, DataAttr
    end

    class Spawn < Node
      defattr :expr, RecAttr
    end

    class Command < Node
      defattr :head, RecAttr
      defattr :args, ListRecAttr
    end

    class Block < Node
      defattr :lines, ListRecAttr
    end

  end
end
