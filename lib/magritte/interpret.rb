module Magritte
  module Interpret
    def self.interpret(ast)
      Interpreter.new.visit(ast)
    end

    class Interpreter < Tree::Walker
      def visit_default(node)
        raise "TODO #{node.inspect}"
      end

      def visit_variable(node)
        yield Proc.current.env.get(node.name)
      end

      def visit_lex_variable(node)
        yield Proc.current.env.get(node.name)
      end

      def visit_string(node)
        Value::String.new(node.value)
      end

      def visit_command(node)
        args = []
        command = visit(node.head)
        node.args.each { |child| visit(child) { |x| args << x } }
        command.call(args).each { |x| yield x}
      end

      def visit_vector(node)
        elems = []
        elems = node.elems.each { |child| visit(child) { |x| elems << x } }
        yield Value::Vector.new(elems)
      end

      def visit_block(node)
        node.elems.each { |child| visit(child) {} }
      end
    end
  end
end
