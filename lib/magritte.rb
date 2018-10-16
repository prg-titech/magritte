require 'thread'

module Magritte
  def self.reload!
    Object.send(:remove_const, :Magritte)
    load __FILE__
    self
  end

  LIB_DIR = File.dirname(__FILE__)
  load "#{LIB_DIR}/magritte/log.rb"

  # Runtime
  load "#{LIB_DIR}/magritte/std.rb"
  load "#{LIB_DIR}/magritte/code.rb"
  load "#{LIB_DIR}/magritte/channel.rb"
  load "#{LIB_DIR}/magritte/proc.rb"
  load "#{LIB_DIR}/magritte/value.rb"
  load "#{LIB_DIR}/magritte/env.rb"

  # AST
  load "#{LIB_DIR}/magritte/tree.rb"
  load "#{LIB_DIR}/magritte/ast.rb"
  load "#{LIB_DIR}/magritte/free_vars.rb"

  # Parsing
  load "#{LIB_DIR}/magritte/lexer.rb"
end
