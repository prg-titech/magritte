module Magritte
  module AST
    class Variable < Tree::Node
      defdata :name

      def repr; "$#{name}"; end
    end

    class LexVariable < Tree::Node
      defdata :name

      def repr; "%#{name}"; end
    end

    class Binder < Tree::Node
      defdata :name

      def repr; "?#{name}"; end
    end

    class String < Tree::Node
      defdata :value

      def repr; value.inspect; end
    end

    class Number < Tree::Node
      defdata :value

      def repr; value.inspect; end
    end

    class StringPattern < Tree::Node
      defdata :value

      def repr; "~#{value.inspect}"; end
    end

    class VectorPattern < Tree::Node
      deflistrec :patterns
      defopt :rest

      def repr; "~[#{(patterns + [rest].compact).map(&:repr).join(' ')}]"; end
    end

    class DefaultPattern < Tree::Node
      def repr; "_"; end
    end

    class RestPattern < Tree::Node
      defrec :binder

      def repr; "*#{binder.repr}"; end
    end

    class Lambda < Tree::Node
      defdata :name
      deflistrec :patterns
      deflistrec :bodies
      defdata :range

      def initialize(*)
        super
        raise "Pattern and body mismatch" unless patterns.size == bodies.size
      end

      def repr
        out = "("
        out << patterns.zip(bodies).map do |(pat, bod)|
          "#{pat.repr} => #{bod.repr}"
        end.join('; ')
        out << ')'
        out
      end
    end

    class Pipe < Tree::Node
      defrec :producer
      defrec :consumer

      def repr; "#{producer.repr} | #{consumer.repr}"; end
    end

    class Or < Tree::Node
      defrec :lhs
      defrec :rhs

      def continue?(status)
        status.fail?
      end

      def repr; "#{lhs.parrepr} || #{rhs.parrepr}"; end
    end

    class And < Tree::Node
      defrec :lhs
      defrec :rhs

      def continue?(status)
        status.normal?
      end

      def repr; "#{lhs.parrepr} && #{rhs.parrepr}"; end
    end

    class Else < Tree::Node
      defrec :lhs
      defrec :rhs

      def repr; "#{lhs.parrepr} !! #{rhs.parrepr}"; end
    end

    class Compensation < Tree::Node
      defrec :expr
      defrec :compensation
      defdata :range
      defdata :unconditional

      def repr
        "#{expr.repr} #{unconditional ? '%%!' : '%%'} #{compensation.parrepr}"
      end
    end

    class Spawn < Tree::Node
      defrec :expr

      def repr
        "& #{expr.repr}"
      end
    end

    class Redirect < Tree::Node
      defdata :direction
      defrec :target

      def repr
        "#{direction} #{target.repr}"
      end
    end

    class With < Tree::Node
      deflistrec :redirects
      defrec :expr

      def repr
        "#{expr.repr} #{redirects.map(&:repr).join(' ')}"
      end
    end

    class Command < Tree::Node
      deflistrec :vec
      defdata :range

      def initialize(*)
        super
        raise "Empty command" unless vec.any?
      end

      def repr; vec.map(&:repr).join(' '); end
    end

    class Block < Tree::Node
      defrec :group

      def repr; "(@block #{group.repr})"; end
    end

    class Group < Tree::Node
      deflistrec :elems

      def repr; elems.map(&:repr).join('; '); end
    end

    class Subst < Tree::Node
      defrec :group

      def repr; "(#{group.repr})"; end
    end

    class Vector < Tree::Node
      deflistrec :elems

      def repr; "[#{elems.map(&:repr).join(' ')}]"; end
    end

    class Environment < Tree::Node
      defrec :body

      def repr; "{ #{body.repr} }"; end
    end

    class Access < Tree::Node
      defrec :source
      defrec :lookup

      def repr; "#{source.parrepr}!#{lookup.repr}"; end
    end

    class Assignment < Tree::Node
      deflistrec :lhs
      deflistrec :rhs

      def repr; "#{lhs.map(&method(:lhs_repr)).join(' ')} = #{rhs.map(&:repr).join(' ')}"; end

    private
      def lhs_repr(n)
        return n.value if n.is_a? AST::String

        n.repr
      end
    end
  end
end
