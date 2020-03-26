module Magritte
  class Compiler < Tree::Walker
    class Table
      include Enumerable
      def each(&b)
        @table.each(&b)
      end

      attr_reader :table, :rev_table
      def initialize
        @table = []
        @rev_table = {}
      end

      def cache(val)
        @rev_table.fetch(val) { register(val) }
      end

      def register(val)
        id = @rev_table[val] = @table.size
        @table << val
        id
      end

      def size
        @table.size
      end
    end

    class Label
      attr_reader :name, :instrs, :trace
      attr_accessor :addr
      def initialize(name, trace)
        @name = name
        @instrs = []
        @trace = trace
      end

      def <<(a)
        @instrs << a
      end

      def offset_arg(arg)
        case arg
        when Label then arg.addr
        when Integer then arg
        when Lexer::Range then arg.repr
        else raise 'oh no'
        end
      end

      def offset_jumps!
        @instrs.map! do |(name, *args)|
          args.map!(&method(:offset_arg))
          [name, *args]
        end
      end

      def size
        @instrs.size
      end
    end

    def initialize(root)
      @root = root
      @free_vars = FreeVars.scan(@root)
      @symbol_table = Table.new
      @constant_table = Table.new
      @labels = {}
      @current_label = nil
    end

    def label_name(name)
      return name if name == 'main'

      i = 0
      name = name.include?('%') ? name : "#{name}-%"
      try_name = nil
      while !try_name || @labels.key?(try_name)
        i += 1
        try_name = name.gsub('%', "#{i}")
      end

      try_name
    end

    def label(name='label-%', trace=nil, &b)
      name = label_name(name)

      new = @labels[name] = Label.new(name, trace)

      if block_given?
        begin
          @current_label, old = new, @current_label
          yield
        ensure
          @current_label = old
        end
      end

      new
    end

    def sym(str)
      @symbol_table.cache(str)
    end

    def const(value)
      @constant_table.cache(value)
    end

    def emit(*a)
      @current_label << a
    end

    def compile
      label('main') do
        visit(@root)
        emit 'return'
      end

      finalize

      self
    end

    def finalize
      offset = 0
      labels = @labels.values.sort_by(&:name)

      labels.each do |label|
        label.addr = offset
        offset += label.size
      end

      labels.each(&:offset_jumps!)
    end

    def render(out)
      out << @constant_table.size << " constants\n"
      @constant_table.each do |const|
        case const
        when Value::Number
          out << '#' << const.repr
        when Value::String
          out << '"' << const.repr.gsub("\\", "\\\\").gsub("\n", "\\n")
        else raise 'oh no'
        end
        out << "\n"
      end

      out << @symbol_table.size << " symbols\n"
      @symbol_table.each do |sym|
        out << sym << "\n"
      end

      labels = @labels.values.sort_by(&:addr)
      out << labels.size << " labels\n"
      labels.each do |label|
        line = "#{label.name} #{label.addr}"
        line << " #{label.trace.repr}" if label.trace
        out << line << "\n"
      end

      instrs = labels.flat_map(&:instrs)
      out << instrs.size << " instructions\n"
      instrs.each_with_index do |inst, i|
        out << "#{i} " << inst.join(' ') << "\n"
      end

      out
    end

    def visit_default(node)
      error! "Cannot compile #{node.inspect}"
    end

    def visit_variable(node)
      emit 'current-env'
      emit 'ref', sym(node.name)
      emit 'ref-get'
    end

    def visit_lex_variable(node)
      emit 'current-env'
      emit 'ref', sym(node.name)
      emit 'ref-get'
    end

    def visit_string(node)
      emit 'const', const(Value::String.new(node.value))
    end

    def visit_number(node)
      emit 'const', const(Value::Number.new(node.value))
    end

    def visit_intrinsic(node)
      emit 'intrinsic', sym(node.name)
    end

    def visit_command(node)
      emit 'collection'
      collect(node.vec)
      emit 'invoke'
    end

    def visit_vector(node)
      emit 'collection'
      collect(node.elems)
      emit 'vector'
    end

    def visit_group(node)
      node.each(&method(:visit))
    end

    def visit_block(node)
      addr = label('block') { visit(node.group); emit 'return' }

      emit 'current-env'
      emit 'env-extend'
      emit 'frame', addr
    end

    def visit_subst(node)
      require 'pry'; binding.pry
      raise 'should not get here'
    end

    def visit_pipe(node)
      lhs_addr = label('pipe-lhs') { visit(node.producer); emit 'return' }
      rhs_addr = label('pipe-rhs') { visit(node.consumer); emit 'return' }

      emit 'current-env'
      emit 'env-extend'
      emit 'channel'
      emit 'env-pipe', 0, 0

      emit 'spawn', lhs_addr
      emit 'frame', rhs_addr
    end

    def visit_spawn(node)
      addr = label('spawn') { visit(node.expr) }
      emit 'spawn', addr
    end

    def compile_patterns(patterns, bodies, failto, contto)
      start_label = @current_label
      labels = patterns.map { label('pattern') }
      fallthrough = labels[1..] + [failto]

      patterns.zip(labels, fallthrough, bodies) do |pat, label, failto, body|
        body_label = label('body') do
          # we assume the match-bound env is on the stack,
          # and the closure is already bound
          visit(body)
          emit 'current-env'
          emit 'env-extend'
          emit 'swap'
          emit 'env-merge'
        end

        PatternCompiler.new(self, failto, body_label).visit(pat)
      end
    end

    def visit_lambda(node)
      # TODO: make this global or unnecessary
      crash = label('crash') { emit 'crash' }
      cont = label('cont')

      addr = label('lambda', node.range) do
        compile_patterns(node.patterns, node.bodies, crash, cont)
      end

      free = @free_vars[node]
      emit 'env'
      free.sort.each do |var|
        # env
        emit 'dup'

        # val
        emit 'current-env'
        emit 'ref', sym(var)
        emit 'ref-get'

        emit 'let', sym(var)
      end

      emit 'closure', addr
    end

    def visit_assignment(node)
      # TODO: multi-assign
      raise 'oops' unless node.lhs.size == 1 && node.rhs.size == 1

      emit 'collection'
      collect(node.rhs)

      node.lhs.each_with_index do |bind, i|
        emit 'index', i

        case bind
        when AST::String
          emit 'current-env'
          emit 'swap'
          emit 'let', sym(bind.value)
        when AST::Variable, AST::LexVariable
          emit 'current-env'
          emit 'ref', sym(bind.name)
          emit 'swap'
          emit 'ref-set'
        when AST::Access
          visit(bind.source)
          visit(bind.lookup)
          emit 'dynamic-ref'
          emit 'swap'
          emit 'ref-set'
        end
      end
    end

    def visit_access(node)
      visit(node.source)
      visit(node.lookup)
      emit 'dynamic-ref'
      emit 'ref-get'
    end

    def visit_environment(node)
      addr = label('env') { visit node.body; emit 'return' }

      emit 'current-env'
      emit 'env-extend'
      emit 'dup' # duplicate the env so it's still on the stack after return
      emit 'frame', addr
      emit 'env-unhinge'
    end

    def visit_with(node)
      emit 'current-env'
      emit 'env-extend'
      counts = { :< => -1, :> => -1 }

      node.redirects.each do |redir|
        emit 'dup'
        visit(redir.target)
        idx = (counts[redir.direction] += 1)
        inst = "env-set-#{redir.direction == :< ? 'input' : 'output'}"

        emit inst, idx
      end

      emit 'frame', label('with') { visit(node.expr); emit 'return' }
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

    def guard(cond, else_)
      visit(cond.lhs)
      final_label = label('guarded')

      antecedent = label('antecedent') do
        visit(cond.rhs)
        emit 'jump', final_label
      end

      otherwise = final_label
      otherwise = label('otherwise') do
        visit(else_)
        emit 'jump', final_label
      end if else_

      ifpass, iffail = case cond
      when AST::And then [antecedent, otherwise]
      when AST::Or then [otherwise, antecedent]
      end

      emit 'last-status'
      emit 'jumpfail', iffail
      emit 'jump', ifpass

      @current_label = final_label
    end

    # assume a collection of values is on the stack.
    # every visit should leave it only on the stack.

    class PatternCompiler < Tree::Walker
      # should fail to the failto label, or continue to the contto label
      # with the new env on the stack
      def initialize(compiler, failto, contto)
        @compiler = compiler
        @failto = failto
        @contto = contto
      end

      def emit(*a); @compiler.emit(*a); end
      def label(*a, &b); @compiler.label(*a, &b); end
      def const(*a, &b); @compiler.const(*a, &b); end
      def sym(*a, &b); @compiler.sym(*a, &b); end

      def compile(node)
        visit_root_pattern(node)
      end

      def visit_default(node)
        raise "Cannot compile #{node.inspect}"
      end

      def visit_binder(node)
        emit 'dup'
        emit 'current-env'
        emit 'swap'
        emit 'let', sym(node.name)
      end

      def visit_vector_pattern(node)
        node.patterns.each_with_index do |el_pattern, i|
          emit 'index', i
          visit(el_pattern)
        end
      end

      def visit_default_pattern(node)
        emit 'pop'
      end

      def visit_string_pattern(node)
        emit 'dup'
        emit 'typeof'
        emit 'const', const('string')
        emit 'jumpne', @failto
      end
    end


    def collect(nodes)
      nodes.each do |node|
        case node
        when AST::Subst
          addr = label('subst') { visit(node.group); emit 'return' }

          emit 'current-env'
          emit 'env-extend'
          emit 'env-collect'
          emit 'frame', addr
        else
          visit(node)
          emit 'collect'
        end
      end
    end
  end
end
