interpret_spec "lexical variables" do
  interpret "basic" do
    source <<-EOF
      (?x => put %x) 1
    EOF

    result "1"
  end

  interpret "assignment" do
    source <<-EOF
      x = 2
      put %x
    EOF

    result "2"
  end

  interpret "dynamic assignment" do
    source <<-EOF
      x = 2
      $x = -1
      put %x
    EOF

    result "-1"
  end

  interpret "lexical assignment" do
    source <<-EOF
      x = 2
      %x = -1
      put $x
    EOF

    result "-1"
  end

  interpret "access assignment" do
    source <<-EOF
      e = { v = 2 }
      $e!v = 13
      put $e!v
    EOF

    result "13"
  end

  interpret "mutation" do
    source <<-EOF
      x = 1
      (get-x) = put %x
      (set-x ?v) = (%x = $v)
      set-x 10
      get-x
    EOF

    result "10"
  end

  interpret "shadowing" do
    source <<-EOF
      x = 100
      f = (?y => add %x %y)
      x = 0
      f 3
    EOF

    result "103"
  end

  interpret "missing closure variables" do
    source <<-EOF
      f = (=> put (=> put %x))
      put should-have-crashed
    EOF

    results []
    status :crash?
  end
end
