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

    class String < Tree::Node
      defdata :value
    end

    class Lambda < Tree::Node
      defdata :name
      deflistrec :patterns
      deflistrec :bodies
    end

    class Pipe < Tree::Node
      defrec :input
      defrec :output
    end

    class Compensation < Tree::Node
      defrec :expr
      defrec :compensation
      defdata :unconditional
    end

    class Spawn < Tree::Node
      defrec :expr
    end

    class Redirect < Tree::Node
      defdata :direction
      defrec :target
    end

    class Command < Tree::Node
      defrec :head
      deflistrec :args
      deflistrec :redirects
    end

    class Block < Tree::Node
      deflistrec :elems
    end

    class Vector < Tree::Node
      deflistrec :elems
    end

    class Access < Tree::Node
      defrec :source
      defrec :lookup
    end
  end
end
