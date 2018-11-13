module Magritte
  module Interpret

    def self.interpret(ast)
      Interpreter.new.interpret(ast)
    end

    class Interpreter < Tree::Walker
      include Code::DSL

      def interpret(ast)
        visit_exec(ast)
      end

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
        yield Value::String.new(node.value)
      end

      def visit_number(node)
        yield Value::Number.new(node.value)
      end

      def visit_command(node)
        vec = visit_collect_all(node.vec)
        command, *args = vec

        raise RuntimeError.new("Empty command") unless command

        command.call(args)
      end

      def visit_vector(node)
        elems = visit_collect_all(node.elems)
        yield Value::Vector.new(elems)
      end

      def visit_block(node)
        node.elems.each { |elem| visit_exec(elem) }
      end

      def visit_subst(node)
        s_ do
          node.elems.each { |elem| visit_exec(elem) }
        end.collect.each { |x| yield x }
      end

      def visit_pipe(node)
        c = Channel.new
        s_ { visit_exec(node.producer) }.into(c).go
        s_ { visit_exec(node.consumer) }.from(c).call
      end

      def visit_spawn(node)
        s_ { visit_exec(node.expr) }.go
      end

      def visit_lambda(node)
        free_vars = FreeVars.of(node)
        yield Value::Function.new(node.name, Proc.current.env.slice(free_vars), node.patterns.map(&:name), node.bodies)
      end

      def visit_assignment(node)
        values = visit_collect_all(node.rhs)
        node.lhs.zip(values) do |bind, val|
          case bind
          when AST::String
            Proc.current.env.let(bind.value, val)
          when AST::Variable
            Proc.current.env.set(bind.value, val)
          when AST::LexVariable
            raise "TODO"
          end
        end
      end

    private
      def visit_exec(node)
        visit(node) {}
      end

      def visit_collect(node)
        enum_for(:visit, node).to_a
      end

      def visit_collect_all(nodes)
        out = []
        nodes.each { |child| visit(child) { |x| out << x } }
        out
      end
    end
  end
end
