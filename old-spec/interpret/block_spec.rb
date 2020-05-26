interpret_spec "block and other grouping constructs" do
  interpret "block scoping" do
    source <<-EOF
      x = 1
      put (x = 2; put $x)
      (x = 3; put $x)
      put $x
    EOF

    results %w(2 3 1)
  end

  interpret "root-level blocks" do
    source <<-EOF
      (put 1)
    EOF

    result "1"
  end

end
