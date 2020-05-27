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

  load "#{LIB_DIR}/log.rb"

  # AST
  load "#{LIB_DIR}/tree.rb"
  load "#{LIB_DIR}/ast.rb"
  load "#{LIB_DIR}/free_vars.rb"

  # Lexer/Parser
  load "#{LIB_DIR}/lexer.rb"
  load "#{LIB_DIR}/skeleton.rb"
  load "#{LIB_DIR}/matcher.rb"
  load "#{LIB_DIR}/parser.rb"

  # Compiler
  load "#{LIB_DIR}/value.rb"
  load "#{LIB_DIR}/compiler.rb"

  load "#{LIB_DIR}/cli.rb"
end
