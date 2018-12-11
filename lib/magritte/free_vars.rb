module Magritte
  module FreeVars
    def self.scan(node)
      Scanner.new.collect(node, Set.new)
    end

    class BinderScanner < Tree::Collector
      def visit_binder(node)
        Set.new([node.name])
      end
    end

    class Scanner < Tree::Collector
      def visit_lex_variable(node, bound_vars)
        Set.new([node.name])
      end

      def visit_lambda(node, bound_vars)
        out = Set.new
        node.patterns.zip(node.bodies) do |pat, body|
          binders = BinderScanner.new.collect_one(pat)
          out.merge(shadow(body, bound_vars, binders))
        end
        #p :lambda_free => [node.name, out]
        out
      end

      def visit_subst(node, bound_vars)
        visit_block(node, bound_vars)
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
