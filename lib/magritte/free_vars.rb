module Magritte
  module FreeVars
    def self.scan(node)
      Scanner.new.collect(node, Set.new)
    end

    class Scanner < Tree::Collector
      def visit_lex_variable(node, bound_vars)
        Set.new([node.name])
      end

      def visit_lambda(node, bound_vars)
        unless node.patterns.all? { |n| n.is_a? AST::Binder }
          raise "Not implemented yet!"
        end
        to_bind = node.patterns.map(&:name)
        shadow(node.bodies, bound_vars, to_bind)
      end

      def visit_block(node, bound_vars)
        out = Set.new
        so_far = Set.new
        node.elems.each do |elem|
          case elem
          when AST::Assignment
            recursive = so_far.dup
            elem.lhs.each do |binder|
              recursive << binder.value if binder.is_a?(AST::String)
              out.merge(shadow([binder], bound_vars, so_far))
            end

            elem.rhs.each do |el|
              out.merge(shadow([el], bound_vars, el.is_a?(AST::Lambda) ? recursive : so_far))
            end

            so_far = recursive
          else
            out.merge(shadow([elem], bound_vars, so_far))
          end
        end

        out
      end

      def shadow(node, bound_vars, shadow_vars)
        collect_from(node, bound_vars + shadow_vars) - shadow_vars
      end
    end
  end
end
