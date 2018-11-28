require 'thread'

module Magritte
  def self.reload!
    Object.send(:remove_const, :Magritte)
    load __FILE__
    self
  end

  class CompileError < StandardError
  end

  class RuntimeError < StandardError
  end

  LIB_DIR = File.dirname(__FILE__)
  ROOT_DIR = File.dirname(LIB_DIR)
  load "#{LIB_DIR}/magritte/log.rb"

  # AST
  load "#{LIB_DIR}/magritte/tree.rb"
  load "#{LIB_DIR}/magritte/ast.rb"
  load "#{LIB_DIR}/magritte/free_vars.rb"

  # Lexer/Parser
  load "#{LIB_DIR}/magritte/lexer.rb"
  load "#{LIB_DIR}/magritte/skeleton.rb"
  load "#{LIB_DIR}/magritte/matcher.rb"
  load "#{LIB_DIR}/magritte/parser.rb"

  # Runtime
  load "#{LIB_DIR}/magritte/status.rb"
  load "#{LIB_DIR}/magritte/std.rb"
  load "#{LIB_DIR}/magritte/code.rb"
  load "#{LIB_DIR}/magritte/channel.rb"
  load "#{LIB_DIR}/magritte/streamer.rb"
  load "#{LIB_DIR}/magritte/proc.rb"
  load "#{LIB_DIR}/magritte/value.rb"
  load "#{LIB_DIR}/magritte/env.rb"
  load "#{LIB_DIR}/magritte/builtins.rb"
  load "#{LIB_DIR}/magritte/interpret.rb"
  load "#{LIB_DIR}/magritte/repl.rb"
end
