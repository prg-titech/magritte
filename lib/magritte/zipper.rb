module Magritte
  class Zipper
    def self.root(tree)
      new(tree, nil, [], [])
    end

    def initialize(node, parent, left, right)
      @node = node
      @parent = parent
      @left = left
      @right = right
    end

    def down
    end

    def last?
      @right.empty?
    end

    def forward

    end
  end

  class ZipWalker < Tree::Visitor
    def initialize(root)
      @root = root
      @zipper = Zipper.root(@root)
    end

    def visit(node, *args)
    end
  end
end
