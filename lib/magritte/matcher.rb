module Magritte
  module Matcher
    class MatchFail < StandardError
    end

    class Base < Tree::Node
      def match_vars(skel)
        return enum_for(:test, skel).to_a
      rescue MatchFail
        nil
      end

      def test(skel,&b)
        raise "Not implemented!"
      end

      def ~@
        Capture[self]
      end

    protected
      def fail!
        raise MatchFail.new
      end

      def matches?(skel, &b)
        out = []
        test(skel) { |x| out << x } # What exaclty is x? test doesn't seem to either return nor yield anything
      rescue MatchFail
        return false
      else
        out.each { |x| b.call x }
        true
      end
    end

    class Ignore < Base
      def test(skel, &b)
      end
    end

    class Empty < Base
      def test(skel, &b)
        fail! unless skel.is_a? Skeleton::Item
        fail! unless skel.elems.empty?
      end
    end

    class TokenType < Base
      defdata :type

      def test(skel, &b)
        fail! unless skel.is_a? Skeleton::Token
        fail! unless skel.token.is? type
      end
    end

    class Item < Base
      def test(skel, &b)
        fail! unless skel.is_a? Skeleton::Item
      end
    end

    class Singleton < Base
      defrec :matcher

      def test(skel, &b)
        fail! unless skel.is_a? Skeleton::Item
        fail! unless skel.elems.size == 1
        fail! unless matcher.matches?(skel.elems.first, &b)
      end
    end

    class Capture < Base
      defrec :matcher

      def test(skel, &b)
        fail! unless matcher.matches?(skel, &b)
        yield skel
      end
    end

    class Nested < Base
      defdata :open_type
      defrec :matcher

      def test(skel, &b)
        fail! unless skel.is_a?(Skeleton::Nested)
        fail! unless skel.open.is?(open_type)
        fail! unless matcher.matches?(Skeleton::Item[skel.elems], &b) # Why do we wrap the elems in an Item?
      end
    end

    class LSplit < Base
      defrec :before
      defrec :split
      defrec :after

      def test(skel, &block)
        fail! unless skel.is_a? Skeleton::Item
        matched = false
        before = []
        after = []
        skel.elems.each do |elem|
          next after << elem if matched
          next before << elem unless self.split.matches?(elem, &block)
          matched = true
        end
        fail! unless matched
        fail! unless self.before.matches?(Skeleton::Item[before], &block)
        fail! unless self.after.matches?(Skeleton::Item[after], &block)
      end
    end

    class RSplit < Base
      defrec :before
      defrec :split
      defrec :after

      def test(skel, &block)
        fail! unless skel.is_a? Skeleton::Item
        matched = false
        before = []
        after = []
        skel.elems.reverse_each do |elem|
          next before << elem if matched
          next after << elem unless self.split.matches?(elem, &block)
          matched = true
        end
        fail! unless matched
        fail! unless self.before.matches?(Skeleton::Item[before.reverse], &block)
        fail! unless self.after.matches?(Skeleton::Item[after.reverse], &block)
      end
    end

    class All < Base
      defrec :matcher

      def test(skel, &b)
        fail! unless skel.is_a? Skeleton::Item
        skel.elems.each do |elem|
          fail! unless self.matcher.matches?(elem, &b)
        end
      end
    end

    class Any < Base
      deflistrec :matchers

      def test(skel, &b)
        matchers.each do |matcher|
          return if matcher.matches?(skel, &b)
        end
        fail!
      end
    end

    module DSL
      def token(type)
        TokenType[type]
      end

      def nested(type, matcher)
        Nested[type, matcher]
      end

      def singleton(matcher)
        Singleton[matcher]
      end

      def starts(elem, rest)
        lsplit(empty, elem, rest)
      end

      def ends(elem, rest)
        rsplit(rest, elem, empty)
      end

      def lsplit(before, split, after)
        LSplit[before, split, after]
      end

      def rsplit(before, split, after)
        RSplit[before, split, after]
      end

      def any(*args)
        Any[args]
      end

      def all(*args)
        All[args]
      end

      def _
        Ignore[]
      end

      def empty
        Empty[]
      end
    end
  end
end
