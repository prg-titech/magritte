module Magritte
  module AST

    class Variable < Tree::Node
      defdata :name
    end

    class LexVariable < Tree::Node
      defdata :name
    end

    class Binder < Tree::Node
      defdata :name
    end

    class Lambda < Tree::Node
      defdata :name
      deflistrec :patterns
      deflistrec :bodies
    end

    class Pipe < Tree::Node
      defrec :input
      defrec :output
      deflistrec :redirects
    end

    class Compensation < Tree::Node
      defrec :expr
      defrec :compensation
      defdata :unconditional
    end

    class Spawn < Tree::Node
      defrec :expr
    end

    class Command < Tree::Node
      defrec :head
      deflistrec :args
    end

    class Block < Tree::Node
      deflistrec :lines
    end
  end
end
