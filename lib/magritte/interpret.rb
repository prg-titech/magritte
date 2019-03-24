module Magritte
  module Interpret

    def self.interpret(ast)
      Interpreter.new(ast).interpret
    end

    class Interpreter < Tree::Walker
      include Code::DSL

      def initialize(root)
        PRINTER.p(:interpret => root)
        @root = root
        @free_vars = FreeVars.scan(@root)
      end

      def interpret
        visit_exec(@root)
      end

      def visit_default(node)
        error! "Cannot interpret as an expression: #{node.inspect}"
      end

      def visit_variable(node)
        yield Proc.current.env.get(node.name)
        Status.normal
      rescue Env::MissingVariable => e
        error!(e.to_s)
      end

      def visit_lex_variable(node)
        yield Proc.current.env.get(node.name)
        Status.normal
      rescue Env::MissingVariable => e
        error!(e.to_s)
      end

      def visit_string(node)
        yield Value::String.new(node.value)
        Status.normal
      end

      def visit_number(node)
        yield Value::Number.new(node.value)
        Status.normal
      end

      def visit_command(node)
        vec = visit_collect_all(node.vec)
        command, *args = vec

        error!("Empty command") unless command

        PRINTER.puts "> #{node.range}"
        command.call(args, node.range)
      end

      def visit_vector(node)
        elems = visit_collect_all(node.elems)
        yield Value::Vector.new(elems)
        Status.normal
      end

      def visit_group(node)
        out = Status.normal
        node.elems.each { |elem| out = visit_exec(elem) }
        out
      end

      def visit_block(node)
        Proc.enter_frame(Proc.current.env.extend) do
          elems = node.group.elems.dup
          last = elems.pop

          elems.each do |elem|
            visit_exec(elem)
          end

          if last
            Proc.current.frame.tail!
            visit_exec(last)
          else
            Status.normal
          end
        end
      end

      def visit_subst(node)
        out = nil
        s_ do
          out = visit_exec(node.group)
        end.collect.each { |x| yield x }
        out
      end

      def visit_pipe(node)
        c = Channel.new
        s_ { visit_exec(node.producer) }.into(c).go
        s_ { visit_exec(node.consumer) }.from(c).call
      end

      def visit_spawn(node)
        s_ {
          Proc.current.frame.tail!
          visit_exec(node.expr)
        }.go
        Status.normal
      end

      def visit_lambda(node)
        free_vars = @free_vars[node]
        yield Value::Function.new(node.name, Proc.current.env.slice(free_vars), node.patterns, node.bodies)
        Status.normal
      rescue Env::MissingVariable => e
        error!(e.to_s)
      end

      def visit_assignment(node)
        values = visit_collect_all(node.rhs)
        error! "not enough values for assignment" if node.lhs.size > values.size

        node.lhs.zip(values) do |bind, val|
          case bind
          when AST::String
            Proc.current.env.let(bind.value, val)
          when AST::Variable, AST::LexVariable
            Proc.current.env.mut(bind.name, val)
          when AST::Access
            # Pretty much code duplication with visit_access, should be improved
            source = visit_one(bind.source)
            lookup = visit_one(bind.lookup)
            error!("Cannot lookup, non-string key #{lookup.repr}") unless lookup.is_a?(Value::String)
            error!("Cannot lookup key #{lookup.repr} in #{source.repr}") unless source.is_a?(Value::Environment)
            source.env.let(lookup.value, val)
          end
        end
        Status.normal
      end

      def visit_access(node)
        source = visit_one(node.source)
        lookup = visit_one(node.lookup)
        error!("Cannot lookup, non-string key #{lookup.repr}") unless lookup.is_a?(Value::String)
        error!("Cannot lookup key #{lookup.repr} in #{source.repr}") unless source.is_a?(Value::Environment)
        yield source.env.get(lookup.value)
      end

      def visit_environment(node)
        env = Std.in_new_env(Proc.current.env) do
          visit_exec(node.body)
        end

        yield Value::Environment.new(env)
      end

      def visit_with(node)
        inputs = []
        outputs = []
        redir_vals = node.redirects.map { |redirect| [redirect.direction, visit_collect(redirect.target).first] }
        redir_vals.each do |(dir, c)|
          PRINTER.p("redirect #{dir} #{c.class} #{c.inspect}")
          error!("Cannot redirect #{dir} #{c.repr}") unless c.is_a?(Value::Channel)
          if dir == :<
            inputs << c.channel
          else
            outputs << c.channel
          end
        end
        Proc.enter_frame(Proc.current.env.extend(inputs, outputs)) do
          visit_exec(node.expr)
        end
      end

      def visit_compensation(node)
        visit_exec(node.expr)
        name = "compensation@"
        func = Value::Function.new(name, Env.empty, [AST::VectorPattern[[], nil]], [node.compensation])
        Proc.current.add_compensation(Value::Compensation.new(func, node.range, node.unconditional))
      end

      def visit_and(node)
        guard(node, nil)
      end

      def visit_or(node)
        guard(node, nil)
      end

      def visit_else(node)
        guard(node.lhs, node.rhs)
      end

    private
      def guard(cond, else_)
        status = visit_exec(cond.lhs)

        if cond.continue?(status)
          visit_exec(cond.rhs)
        elsif else_
          visit_exec(else_)
        else
          status
        end
      end

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

      def visit_one(node)
        out = visit_collect(node)
        error!("Must resolve to one value") unless out.size == 1
        out.first
      end

      def error!(msg)
        Proc.current.crash!(msg)
      end
    end
  end
end
