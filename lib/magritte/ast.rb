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

    class Number < Tree::Node
      defdata :value
    end

    class StringPattern < Tree::Node
      defdata :value
    end

    class VectorPattern < Tree::Node
      deflistrec :patterns
      defopt :rest
    end

    class DefaultPattern < Tree::Node
    end

    class Lambda < Tree::Node
      defdata :name
      deflistrec :patterns
      deflistrec :bodies

      def initialize(*)
        super
        raise "Pattern and body mismatch" unless patterns.size == bodies.size
      end
    end

    class Pipe < Tree::Node
      defrec :producer
      defrec :consumer
    end

    class Or < Tree::Node
      defrec :lhs
      defrec :rhs

      def continue?(status)
        status.fail?
      end
    end

    class And < Tree::Node
      defrec :lhs
      defrec :rhs

      def continue?(status)
        status.normal?
      end
    end

    class Else < Tree::Node
      defrec :lhs
      defrec :rhs
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

    class With < Tree::Node
      deflistrec :redirects
      defrec :expr
    end

    class Command < Tree::Node
      deflistrec :vec

      def initialize(*)
        super
        raise "Empty command" unless vec.any?
      end
    end

    class Block < Tree::Node
      defrec :group
    end

    class Group < Tree::Node
      deflistrec :elems
    end

    class Subst < Tree::Node
      defrec :group
    end

    class Vector < Tree::Node
      deflistrec :elems
    end

    class Environment < Tree::Node
      defrec :body
    end

    class Access < Tree::Node
      defrec :source
      defrec :lookup
    end

    class Assignment < Tree::Node
      deflistrec :lhs
      deflistrec :rhs
    end
  end
end
