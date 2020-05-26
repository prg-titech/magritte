require 'thread'

module Magritte
  def self.reload!
    Object.send(:remove_const, :Magritte)
    load __FILE__
    self
  end

  class CompileError < StandardError
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

  # Compiler
  load "#{LIB_DIR}/magritte/value.rb"
  load "#{LIB_DIR}/magritte/compiler.rb"

  load "#{LIB_DIR}/magritte/cli.rb"
end
