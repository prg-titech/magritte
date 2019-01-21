module Magritte
  module Pattern

    def self.evaluate(node, val, env)
      Evaluator.new(env.extend).evaluate(node, val)
    end

    class Evaluator < Tree::Visitor

      class PatternFail < StandardError
      end

      def initialize(env)
        @env = env
      end

      def evaluate(node, val)
        visit(node, val)
      rescue PatternFail
        nil
      else
        @env
      end

      def visit_default(node, val)
        raise "TODO"
      end

      def visit_binder(node, val)
        @env.let(node.name, val)
      end

      def visit_string_pattern(node, val)
        fail! unless val.is_a?(Value::String)
        fail! unless node.value == val.value
      end

      def visit_default_pattern(node, val)
        #pass
      end

      def visit_vector_pattern(node, val)
        fail! unless val.is_a?(Value::Vector)

        patterns = node.patterns
        values = val.elems
        # Check that the size is right
        fail! unless node.rest.nil? ? patterns.size == values.size : patterns.size <= values.size
        patterns.each_with_index do |pat, i|
          visit(pat, values[i])
        end

        if node.rest
          @env.let(node.rest.binder.name, Value::Vector.new(values[patterns.size..-1]))
        end
      end

      def fail!
        raise PatternFail.new
      end
    end
  end
end
