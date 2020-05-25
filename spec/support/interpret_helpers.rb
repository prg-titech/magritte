require "ostruct"
require 'fileutils'
require 'open3'
require 'timeout'

module InterpretHelpers
  TMP_DIR = Pathname.new('./tmp/spec-build')
  TMP_DIR.mkpath
  VM_PATH = ENV['MAGRITTE_VM'] || './build/magvm'

  def self.included(base)
    base.send(:extend, ClassMethods)

    base.class_eval do
      abstract(:input)

      let(:lex) { Magritte::Lexer.new(input_name, input) }
      let(:skel) { Magritte::Skeleton::Parser.parse(lex) }
      let(:ast) { Magritte::Parser.parse(skel) }
      let(:compiler) { Magritte::Compiler.new(ast).compile }

      let(:do_run) do
        File.open("#{tmp_file}x", 'w') { |f| compiler.render_decomp(f) }
        tmp_file.open('w') { |f| compiler.render(f) }

        env = { 'MAGRITTE_DEBUG_TO' => '2' }
        script = "MAGRITTE_DEBUG_TO=2 #{VM_PATH} #{tmp_file} > #{tmp_file}.out 2>#{tmp_file}.err"

        puts 'SCRIPT'
        puts script

        pid = nil
        begin
          Timeout.timeout(2) do
            pid = Process.spawn(script)
            @status = Process.wait(pid)
          end
        rescue Timeout::Error
          pid && Process.kill('TERM', pid)
        end
      end

      let(:debug) { do_run; File.read("#{tmp_file}.err") }
      let(:result) { do_run; File.read("#{tmp_file}.out").strip }
      let(:status) { do_run; @status }

      let(:results) { result.split("\n") }
    end
  end

  module ClassMethods
    def interpret(description, &b)
      dsl = DSL.new
      spec = dsl.evaluate(&b)
      describe description do
        let(:input) { "load ./mag/prelude.mag\n\n#{spec.source}" }
        let(:input_name) { "#{spec.source_name}: #{self.class.to_s}" }
        let(:tmp_file) { TMP_DIR.join(spec.source_name.gsub(/[^\w]/, '.')) }

        it do
          # puts debug

          source_name = spec.source_name
          if spec.expect_success
            assert { source_name; status == 0 }
          else
            assert { source_name; status && status != 0 }
          end

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
      @expect_succeed = true
    end

    def source(source)
      @source_loc = caller[0]
      @source = source
    end

    def result(*output)
      results(output)
    end

    def expect_fail!
      @expect_succeed = false
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
      OpenStruct.new(
        source: @source,
        result_expectations: @result_expectations,
        expect_success: @expect_success,
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
