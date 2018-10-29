module Magritte
  module Parser
    extend self
    include Matcher::DSL

    def parse_root(skel)
      elems = skel.elems.map do |item|
        parse_line(item)
      end
      AST::Block[elems]
    end

    def parse_line(item)
      item.match(rsplit(~_, token(:pipe), ~_)) do |before, after|
        return AST::Pipe[parse_line(before), parse_line(after)]
      end

      terms = item.elems.map do |term|
        parse_term(term)
      end

      AST::Command[terms]
    end

    def parse_vector(vec)

    end

    def parse_term(term)
      term.match(~token(:var)) do |var|
        return AST::Variable[var.value]
      end

      term.match(~token(:bare)) do |bare|
        return AST::String[bare.value]
      end

      term.match(nested(:lparen,~_)) do |item|
        return parse_block(item)
      end
    end
  end
end
