module Magritte
  module Runtime
    class Proc < Tree::Visitor
      # written to by the scheduler
      attr_accessor :state, :pid

      attr_reader :root

      attr_reader :scheduler
      def initialize(scheduler, exp)
        @scheduler = scheduler
        @root = exp

        @state = :init
        @layers = []

        layer @root
      end

      def start
        env = Env.base.extend([], [@scheduler.new_collector([])])
        frame(env)
        @scheduler.spawn(self)
        env
      end

      def log(msg)
        @scheduler.log("(#{pid}) #{indent}#{msg}")
      end

      def consolidate!
        last = @layers.pop
        nxt = @layers.last
        nxt.push(*last.values) if nxt

        last
      end

      def step
        consolidate! while @layers.any? && @layers.last.done?
        return @state = :done if @layers.empty?

        init_state = @state
        @scheduler.log "(#{pid}) state=#{@state}"
        @layers.each_with_index do |layer, idx|
          @scheduler.log "(#{pid}) #{('  ' * idx)}#{layer.repr}"
        end

        inst = @layers.last.step

        send(inst.name, *inst.args)

        @scheduler.log "(#{pid}) state -> #{@state}" if @state != init_state
        @scheduler.log "======"

        @state
      rescue => e
        @scheduler.log "ERROR #{@layers.last.trace.repr} #{inst.repr}"
        raise
      end

      def visit_subst(node, inst)
        c = @scheduler.new_collector(@layers.last)

        new_env = env.extend([], [c])

        inst.frame(new_env)
        inst.run node.group
        inst.wait_for_close c
      end

      def ret
        frame = @layers.last.frame
        @layers.last.frame = nil
        frame.exit
      end

      def visit_command(node, inst)
        node.each do |child|
          inst.run(child)
        end
        inst.invoke(node.range)
      end

      def visit_vector(node, inst)
        node.each do |child|
          inst.run(child)
        end
        inst.vec
      end

      def visit_string(node, inst)
        inst.push Value::String.new(node.value)
      end

      def visit_number(node, inst)
        inst.push Value::Number.new(node.value.to_f)
      end

      def visit_group(node, inst)
        node.elems.each do |elem|
          inst.run elem
        end
      end

      def visit_lambda(node, inst)
        # TODO: don't re-scan
        free_vars = FreeVars.scan(node)[node]
        captured = env.slice(free_vars)
        fn = Value::Function.new(node.name, captured, node.patterns, node.bodies)
        inst.push fn
      end

      def visit_lex_variable(node, inst)
        inst.push env.get(node.name)
      end

      def visit_block(node, inst)
        inst.frame(env)
        inst.run node.group
      end

      def visit_assignment(node, inst)
        node.rhs.each do |r|
          inst.run r
        end

        node.lhs.each do |l|
          case l
          when AST::String then inst.let(l.value)
          when AST::Variable, AST::LexVariable then inst.mut(l.name)
          when AST::Access
            inst.run l.source
            inst.run l.lookup
            inst.mut_access
          end
        end
      end

      def visit_pipe(node, inst)
        c = @scheduler.new_channel
        lhs_env = env.extend([], [c])
        rhs_env = env.extend([c], [])

        inst.spawn(node.producer, lhs_env)

        inst.frame(rhs_env)
        inst.run(node.consumer)
      end

      def layer(node, &b)
        b ||= proc { |inst| self.visit(node, inst) }
        new_layer = Layer.gen(node, &b)

        if @layers.last && @layers.last.done?
          old_layer = consolidate!
          if old_layer.frame
            new_layer.merge_frame(old_layer.frame) or old_layer.frame.exit
          end
        end

        @layers << new_layer
      end

      def wait_for_close(c)
        @scheduler.wait_for_close(self, c)
      end

      def frame(env)
        p :frame => env
        f = @layers.last.frame = Frame.new(self, env)
        f.enter
      end

      def push(value)
        @layers.last.push(value)
      end

      def run(node)
        layer(node)
      end

      def spawn(node, env)
        @scheduler.spawn(node, env)
      end

      def indent
        '  ' * (@layers.size - 1)
      end

      def invoke(node)
        do_invoke(node, @layers.last.pop_values)
      end

      def visit_default(node, inst)
        raise "TODO: visit #{node.repr}"
      end

      def env
        @layers.reverse_each do |l|
          return l.frame.env if l.frame
        end

        raise "no frame"
      end

      def do_invoke(node, values)
        invokee, *args = values

        @scheduler.log("invoke #{invokee.repr}(#{args.map(&:repr).join(' ')})")

        case invokee
        when Value::String
          do_invoke(node, [env.get(invokee.value), *args])
        when Value::Vector
          h, *r = invokee.elems
          do_invoke(node, [h, *r, *args])
        when Value::BuiltinFunction
          Builtin.get(invokee.name).run(self, args)
        when Value::Function
          new_env, body = invokee.match(args, env) || raise("todo: crashing")
          layer invokee do |inst|
            inst.frame new_env
            visit(body, inst)
          end
        else
          raise "uncallable #{invokee.repr}"
        end
      end

      def read
        env.stdin.read(self, @layers.last)
      end

      def write
        values = @layers.last.pop_values

        puts "write(#{env.stdout.repr} [#{values.map(&:repr).join(' ')}])"
        env.stdout.write_all(self, values)
      end

      def let(name)
        val = @layers.last.shift or raise "todo crash"
        env.let(name, val)
      end

      def expand
        @layers.last.pop_values.each do |vec|
          crash! unless vec.is_a?(Value::Vector)
          @layers.last.push(*vec.elems)
        end
      end

      def vec
        @layers.last.push(Value::Vector.new(@layers.last.pop_values))
      end

      def interrupt!(channel)
        # TODO
        @state = :done
      end
    end
  end
end
