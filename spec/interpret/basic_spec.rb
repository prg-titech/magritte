interpret_spec "basic functionality" do
  interpret "a vector" do
    source <<-EOF
      put [a b c]
    EOF

    result "[a b c]"
  end

  interpret "single word" do
    source <<-EOF
      put hello
    EOF

    result "hello"
  end

  interpret "nested expression" do
    source <<-EOF
      put (put 1)
    EOF

    result "1"
  end

  interpret "early exit for collectors" do
    source <<-EOF
      put 1 2 3 4 5 6 7 8 9 10 | (& drain; & drain)
    EOF

    results_size 10
  end

  interpret "early exit for vectors" do
    source <<-EOF
      for [0 (put 1 2 3 4 5 6 7 8 9 10 | (& drain; & drain))]
    EOF

    results_size 11
  end

  interpret "slide example" do
    source <<-EOF
      count-forever | (& drain; & drain; & drain) | take 30
    EOF

    results_size 30
  end
end
