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

      def to_s
        "@#{@name}"
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

      self
    end

    def finalize
      return if @finalized
      @finalized = true

      offset = 0
      labels = @labels.values.sort_by(&:name)

      labels.each do |label|
        label.addr = offset
        offset += label.size
      end

      labels.each(&:offset_jumps!)
    end

    def render_decomp(out)
      out << "==== constants\n"
      @constant_table.each_with_index do |const, i|
        out << i << " " << const << "\n"
      end

      out << "==== symbols\n"
      @symbol_table.each_with_index do |sym, i|
        out << i << " " << sym << "\n"
      end

      out << "==== code\n"
      @labels.values.each do |label|
        out << label.name << ":"
        out << " " * [2, 24 - label.name.size].max << label.trace.repr if label.trace
        out << "\n"
        label.instrs.each_with_index do |instr, i|
          out << i << "  " << instr.map(&:to_s).join(' ') << "\n"
        end
      end
    end

    INT_FORMAT = 'L'

    def render_str(out, str)
      out << [str.size].pack(INT_FORMAT)
      out << str
    end

    def render(out)
      finalize

      out << [@constant_table.size].pack(INT_FORMAT)
      @constant_table.each do |const|
        case const
        when Value::Number
          out << '#'
          out << [const.value].pack(INT_FORMAT)
        when Value::String
          out << '"'
          render_str(out, const.value)
        else raise "oh no, #{const.inspect}"
        end
      end

      out << [@symbol_table.size].pack(INT_FORMAT)
      @symbol_table.each do |sym|
        render_str(out, sym)
      end

      labels = @labels.values.sort_by(&:addr)
      out << [labels.size].pack(INT_FORMAT)
      labels.each do |label|
        render_str out, label.name
        out << [label.addr].pack(INT_FORMAT)
        out << (label.trace ? [1] : [0]).pack(INT_FORMAT)
        render_str(out, label.trace.repr) if label.trace
      end

      instrs = labels.flat_map(&:instrs)
      out << [instrs.size].pack(INT_FORMAT)
      instrs.each do |(name, *args)|
        render_str out, name
        out << [args.size, *args].pack("#{INT_FORMAT}*")
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
      emit 'current-env'
      emit 'spawn', addr
    end

    def compile_patterns(name, range, patterns, bodies, failto)
      start_label = @current_label
      labels = (0...patterns.size).map { |i| label("#{name}-#{i}", range) }
      fallthrough = labels[1..] + [failto]

      patterns.zip(labels, fallthrough, bodies) do |pat, label, failto, body|
        @current_label = label
        PatternCompiler.new(self, failto).compile(pat)
        visit(body)
        emit 'return'
      end

      labels
    ensure
      @current_label = start_label
    end

    def visit_lambda(node)
      # TODO: make this global or unnecessary
      crash = label('crash') { emit 'crash' }
      pattern_labels = compile_patterns(node.name, node.range, node.patterns, node.bodies, crash)

      addr = label('lambda', node.range) do
        emit 'jump', pattern_labels.first
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

      emit 'closure', pattern_labels.first
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
      def initialize(compiler, failto)
        @compiler = compiler
        @failto = failto
      end

      def emit(*a); @compiler.emit(*a); end
      def label(*a, &b); @compiler.label(*a, &b); end
      def const(*a, &b); @compiler.const(*a, &b); end
      def sym(*a, &b); @compiler.sym(*a, &b); end

      def compile(node)
        emit 'clear'
        visit(node)
      end

      def visit_default(node)
        raise "Cannot compile #{node.inspect}"
      end

      def visit_binder(node)
        # no dup here - we want to pop off the last value
        emit 'current-env'
        emit 'swap'
        emit 'let', sym(node.name)
      end

      def visit_vector_pattern(node)
        emit 'dup'
        emit 'typeof'
        emit 'const', const(Value::String.new('vector'))
        emit 'jumpne', @failto

        emit 'dup'
        emit 'size'

        if node.rest
          emit 'jumplt', node.patterns.size, @failto
        else
          emit 'noop', sym(node.patterns.size.to_s)
          emit 'const', const(Value::Number.new(node.patterns.size))
          emit 'jumpne', @failto
        end

        node.patterns.each_with_index do |el_pattern, i|
          emit 'noop', sym("vec-index-#{i}")
          emit 'dup'
          emit 'index', i
          visit(el_pattern)
        end

        if node.rest
          emit 'rest', node.patterns.size
          visit(node.rest)
        end
      end

      def visit_rest_pattern(node)
        visit(node.binder)
      end

      def visit_default_pattern(node)
        emit 'pop'
      end

      def visit_string_pattern(node)
        emit 'noop', sym('string_pattern')
        # emit 'dup'
        # emit 'typeof'
        # emit 'const', const(Value::String.new('string'))
        # emit 'jumpne', @failto
        emit 'const', const(Value::String.new(node.value))
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
