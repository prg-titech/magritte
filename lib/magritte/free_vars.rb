module Magritte
  module FreeVars
    def self.scan(node)
      Scanner.new.collect(node, Set.new)
    end

    class Grouper < Tree::Visitor
      def self.group(node)
        new.visit(node)
      end

      def visit_group(node)
        elems = node.elems.map { |e| visit(e) }

        out = []
        while elems.any?
          head = elems.shift

          @pre_decls = []
          @decls = []
          while head && declaration?(head)
            @pre_decls << pre_decl(head)
            @decls << decl_to_mut(head)
            head = elems.shift
          end

          if @decls.any?
            out.concat(@pre_decls)
            out.concat(@decls)
          end

          out << head if head
        end

        AST::Group[out]
      end

    protected
      def pre_decl(node)
        AST::Assignment[node.lhs, [AST::String['__undef__']]]
      end

      def decl_to_mut(node)
        AST::Assignment[[AST::Variable[node.lhs[0].value]], node.rhs]
      end

      def declaration?(node)
        return false unless node.is_a? AST::Assignment
        return false unless node.lhs.size == 1 && node.rhs.size == 1
        return false unless node.lhs[0].is_a? AST::String
        return true if node.rhs[0].is_a? AST::Lambda

        # re-declaration of a constant resets the group
        return false if @decls.any? { |d| d.lhs[0].name == node.lhs[0].value }
        return true if node.rhs[0].is_a? AST::String
        return true if node.rhs[0].is_a? AST::Number

        false
      end
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
        out
      end

      def visit_group(node, bound_vars)
        out = Set.new
        so_far = Set.new

        node.elems.each do |elem|
          case elem
          when AST::Assignment
            recursive = so_far.dup

            elem.lhs.each do |binder|
              recursive << binder.value if binder.is_a?(AST::String)
              out.merge(shadow(binder, bound_vars, so_far))
            end

            elem.rhs.each do |el|
              out.merge(shadow(el, bound_vars, so_far))
            end

            so_far = recursive
          # when AST::LiftGroup
          #   # pre-declare all assignments
          #   elem.elems.each { |assn| so_far << assn.lhs[0].value }

          #   elem.elems.each do |assn|
          #     out.merge(shadow(assn, bound_vars, so_far))
          #   end
          else
            out.merge(shadow(elem, bound_vars, so_far))
          end
        end

        out
      end

      def visit_command(node, bound_vars)
        out = Set.new
        head, *rest = node.vec
        if head.is_a?(AST::String) && bound_vars.include?(head.value)
          out << head.value
        else
          out.merge(visit(head, bound_vars))
        end

        rest.each do |node|
          out.merge(visit(node, bound_vars))
        end

        out
      end

      def shadow(node, bound_vars, shadow_vars)
        visit(node, bound_vars + shadow_vars) - shadow_vars
      end
    end
  end
end
