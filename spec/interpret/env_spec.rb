interpret_spec "environment" do
  interpret "creation" do
    source <<-EOF
      e = {x = 1; y = 0}
      put %e!x %e!y
    EOF

    results %w(1 0)
  end

  interpret "complex creation" do
    source <<-EOF
      x = 1
      y = 0
      e = {z = $x; k = $y}
      put $e!z $e!k
    EOF

    results %w(1 0)
  end

  interpret "nesting" do
    source <<-EOF
      e = {g = 3}
      e2 = {h = 4}
      e3 = {x = $e; y = $e2}
      put $e3!x!g $e3!y!h
    EOF

    results %w(3 4)
  end

  interpret "printing" do
    source <<-EOF
      e = {g = 3; x = 1}
      put $e
    EOF

    result "{ g = 3; x = 1 }"
  end

  interpret "environment functions" do
    source <<-EOF
      e = { x = 2; (f ?y) = (put %x %y) }
      $e!f 1
    EOF

    results %w(2 1)
  end

  interpret "redirecting" do
    source <<-EOF
      e = { x = (make-channel) }
      & put 3 > $e!x
      get < $e!x
    EOF

    results %w(3)
  end
end
