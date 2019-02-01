interpret_spec "standard library" do
  interpret "range" do
    source <<-EOF
      range 5
    EOF

    results ["0", "1", "2", "3", "4"]
  end

  interpret "repeat" do
    source <<-EOF
      repeat 3 7
    EOF

    results ["7", "7", "7"]
  end

  interpret "inc" do
    source <<-EOF
      inc 1
      inc 5
    EOF

    results ["2", "6"]
  end

  interpret "dec" do
    source <<-EOF
      dec 1
      dec 5
    EOF

    results ["0", "4"]
  end

  interpret "all" do
    source <<-EOF
      range 2 | all (?x => lt 10 %x)
    EOF

    results []
  end
end
