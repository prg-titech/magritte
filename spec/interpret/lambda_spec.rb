interpret_spec "lambda functionality" do
  interpret "call" do
    source <<-EOF
      (?x => put $x) 1
    EOF

    result "1"
  end

  interpret "zero argument lambdas" do
    source <<-EOF
      exec (=> put 1)
    EOF

    result "1"
  end

  interpret "reducing argument length patterns" do
    source <<-EOF
      f = (
        ?x ?y => put [two %x %y]
        ?x => put [one %x]
      )

      f 3
      f 5 6
    EOF

    results ["[one 3]", "[two 5 6]"]
  end

  interpret "increasing argument length patterns" do
    source <<-EOF
      f = (
        ?x => put [one %x]
        ?x ?y => put [two %x %y]
      )

      f 3
      f 5 6
    EOF

    results ["[one 3]", "[two 5 6]"]
  end

  interpret "special syntax assignment" do
    source <<-EOF
      (f ?x) = put $x
      f 5
      put $f
    EOF

    results ["5","<func:f>"]
  end

  interpret "special syntax assignment with dynamic var" do
    source <<-EOF
      f = 1
      ($f ?x) = put $x
      f 5
      put $f
    EOF

    results ["5","<func:f>"]
  end

  interpret "special syntax assignment with lexical var" do
    source <<-EOF
      f = 1
      (%f ?x) = put $x
      f 5
      put $f
    EOF

    results ["5","<func:f>"]
  end

  interpret "special syntax assignment with access expression" do
    source <<-EOF
      e = { f = 5 }
      ($e!f ?x) = (inc %x)
      put ($e!f 3)
    EOF

    result "4"
  end

  interpret "body stretching multiple lines" do
    source <<-EOF
      (f ?x) = (
        y = (inc %x)
        z = (inc %y)
        put $z
      )
      put (f 5)
    EOF

    result "7"
  end

  interpret "nested body stretching multiple lines" do
    source <<-EOF
      (f ?x ?y) = (
        z = (?a => (
            put (dec $a) 1
        ))
        put (z $x) $y
      )
      put (f 1 2)
    EOF

    results ["0", "1", "2"]
  end

  interpret "body with anon lambda" do
    source <<-EOF
      put 1 2 3 | each (?a => put 10; put $a)
    EOF

    results %w(10 1 10 2 10 3)
  end

  interpret "vector patterns" do
    source <<-EOF
      f = (
        [one ?x] => put [first %x]
        [two ?y ?z] => put [second %y %z]
        [three] => put [third]
        [four ?q to ?w] => put [fourth %q %w]
        _ => put default
      )

      f [one 1]
      f [two 2 3]
      f [three]
      f [four 4 to 5]

      # default cases
      f [one 1 2]
      f [two]
      f [three 4]
      f [four 5 6]
    EOF

    results ["[first 1]", "[second 2 3]", "[third]", "[fourth 4 5]",
             "default", "default", "default", "default"]
  end

  interpret "variable arguments" do
    source <<-EOF
      (?x (?rest) => put %x; put hello; put %rest) 1 2 3
    EOF

    results %w(1 hello 2 3)
  end
end
