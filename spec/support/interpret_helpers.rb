require "ostruct"
require_relative 'dangling_threads'

module InterpretHelpers
  include DanglingThreads

  def self.included(base)
    base.send(:extend, ClassMethods)

    base.class_eval do
      abstract(:input)

      let(:lex) { Magritte::Lexer.new(input_name, input) }
      let(:skel) { Magritte::Skeleton::Parser.parse(lex) }
      let(:ast) { Magritte::Parser.parse(skel) }
      let(:env) { Magritte::Builtins.load(Magritte::Env.empty) }
      let(:results) { ast;
        collection, @status = with_no_dangling_threads do
          Magritte::Spawn.s_ env do
            Magritte::Interpret.interpret(ast)
          end.collect_with_status
        end

        collection.map(&:to_s)
      }
      let(:status) { results; @status }
      let(:result) { results.join("\n") }
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
      @status_expectations << proc do
        assert { status.send(query) }
      end
    end

    def results(outputs)
      @result_expectations << proc do
        assert { results == outputs }
      end
    end

    def results_size(len)
      @result_expectations << proc do
        assert { results.size == len }
      end
    end

    def debug
      @status_expectations.unshift(proc do
        binding.pry
      end)
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
