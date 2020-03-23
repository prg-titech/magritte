require "ostruct"
module InterpretHelpers
  def self.included(base)
    base.send(:extend, ClassMethods)

    base.class_eval do
      abstract(:input)

      let(:lex) { Magritte::Lexer.new(input_name, input) }
      let(:skel) { Magritte::Skeleton::Parser.parse(lex) }
      let(:ast) { Magritte::Parser.parse(skel) }
      let(:scheduler) { Magritte::Runtime::Scheduler.new(logger: $stdout) }
      let(:output) { scheduler.spawn_root(ast, Magritte::Env.base) }

      let(:result) { output; scheduler.run; output.output }
      let(:results) { output.map(&:repr) }
    end
  end

  module ClassMethods
    def interpret(description, &b)
      dsl = DSL.new
      spec = dsl.evaluate(&b)
      describe description do
        let(:input) { spec.source }
        let(:input_name) { "#{spec.source_name}: #{self.class.to_s}" }

        it do
          spec.status_expectations.each { |b| instance_eval(&b) }
          spec.result_expectations.each { |b| instance_eval(&b) }
        end
      end
    end
  end

  class DSL
    def initialize
      @source = 'crash "source undefined"'
      @source_loc = nil
      @status_expectations = []
      @result_expectations = []
    end

    def source(source)
      @source_loc = caller[0]
      @source = source
    end

    def result(*output)
      results(output)
    end

    def status(query)
      source_loc = @source_loc
      @status_expectations << proc do
        assert { source_loc; status.send(query) }
      end
    end

    def results(outputs)
      source_loc = @source_loc
      @result_expectations << proc do
        assert { source_loc; results == outputs }
      end
    end

    def results_size(len)
      source_loc = @source_loc
      @result_expectations << proc do
        assert { source_loc; results.size == len }
      end
    end

    def debug
      @result_expectations << proc do
        binding.pry
      end
    end

    def evaluate(&b)
      instance_eval(&b)
      status(:normal?) if @status_expectations.empty?
      OpenStruct.new(
        source: @source,
        result_expectations: @result_expectations,
        status_expectations: @status_expectations,
        source_name: self.source_name,
      )
    end

    def source_name
      return '(anon)' if @source_loc.nil?
      @source_loc =~ /\A(.*?:\d+):/
      filename, line = $1.split(':')
      "test@#{filename}:#{line}"
    end

  end
end

def interpret_spec(description, &b)
  describe(description) do
    include InterpretHelpers
    class_eval(&b)
  end
end
