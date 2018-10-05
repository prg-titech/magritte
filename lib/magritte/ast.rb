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

      # Object equality based on 
      # https://stackoverflow.com/questions/1931604/whats-the-right-way-to-implement-equality-in-ruby
      def ==(o)
        o.class == self.class && o.value == @value
      end

      alias eql? ==

      def hash
        [self.class, self.value].hash
      end
    end

    class DataAttr < Attr
      def each(&block)
        #pass
      end

      def map(&block)
        self
      end

      def inspect
        value.inspect
      end
    end

    class RecAttr < Attr
      def each(&block)
        block.call(@value)
      end

      def map(&block)
        RecAttr.new(block.call(@value))
      end

      def inspect
        "*#{value.inspect}"
      end
    end

    class ListRecAttr < Attr
      def each(&block)
        @value.each(&block)
      end

      def map(&block)
        ListRecAttr.new(@value.map(&block))
      end

      def inspect
        "**#{value.inspect}"
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

        def short_name
          @short_name ||= begin
            self.class.name =~ /(?:.*::)?(.*)/
            $1.gsub(/([[:lower:]])([[:upper:]])/) { "#{$1}_#{$2.downcase}" }
              .downcase
          end
        end

        def defattr(name, type)
          attrs << name
          types << type
          index = attrs.size - 1
          define_method name do
            attrs[index].value
          end
        end

        def defdata(name)
          defattr(name, DataAttr)
        end

        def defrec(name)
          defattr(name, RecAttr)
        end

        def deflistrec(name)
          defattr(name, ListRecAttr)
        end

        def make(*attrs)
          if attrs.size != types.size
            raise ArgumentError.new("Expected #{types.size} arguments, got #{attrs.size}")
          end

          new(attrs.zip(types).map { |(value, type)|
            type.new(value)
          })
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

      # Object equality based on 
      # https://stackoverflow.com/questions/1931604/whats-the-right-way-to-implement-equality-in-ruby
      def ==(o)
        o.class == self.class && o.attrs.zip(@attrs).map { |(obj_attr, attr)| obj_attr == attr }.all? 
      end

      alias eql? ==

      def inspect
        "#<#{self.class}#{attrs.inspect}>"
      end

      def hash
        [self.class, *self.attrs].hash
      end

      def accept(visitor, *args, &block)
        visitor.send(:"visit_#{self.class.short_name}", *args, &block)
      end
    end

    class Variable < Node
      defdata :name
    end

    class LexVariable < Node
      defdata :name
    end

    class Binder < Node
      defdata :name
    end

    class Lambda < Node
      defdata :name
      deflistrec :patterns
      deflistrec :bodies
    end

    class Pipe < Node
      defrec :input
      defrec :output
      deflistrec :redirects
    end

    class Compensation < Node
      defrec :expr
      defrec :compensation
      defdata :unconditional
    end

    class Spawn < Node
      defrec :expr
    end

    class Command < Node
      defrec :head
      deflistrec :args
    end

    class Block < Node
      deflistrec :lines
    end

    class Visitor

      def visit(node, *args, &block)
        node.accept(self, *args, &block)
      end

      def visit_default(node, *args, &block)
        node.map { |child| visit(child, *args, &block) }
      end

      def method_missing(method_name, *args, &block)
        if method_name =~ /^visit_/
          visit_default(*args, &block)
        else
          super
        end
      end
    end

  end
end
