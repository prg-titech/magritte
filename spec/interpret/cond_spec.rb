interpret_spec "conditionals" do
  interpret "simple" do
    source <<-EOF
      true && put 1
      false || put 2
      true || put 3
      false && put 4
      true
    EOF

    results %w(1 2)
  end

  interpret "else" do
    source <<-EOF
      true && put 1 !! put 2
      false && put 3 !! put 4
      true || put 5 !! put 6
      false || put 7 !! put 8
    EOF

    results %w(1 4 6 7)
  end

  interpret "try" do
    source <<-EOF
      try crash && put success !! put crashed
    EOF

    result "crashed"
  end

  interpret "equality" do
    source <<-EOF
      eq 10 10 || put fail1
      eq 10 11 && put fail2
      eq foo foo || put fail3
      eq foo bar && put fail4
      eq [1 2] [1 (add 1 1)] || put fail5
      eq [1 2] [1 3] && put fail6
      eq [1 2] [1 2 3] && put fail7
      eq [1 2 3] [1 2] && put fail8
      eq [1 [2 3]] [1 [2 3]] || put fail9
      c = (make-channel)
      eq $c $c || put fail10
      eq $c (make-channel) && put fail11
      true
    EOF

    results []
  end

  interpret "returning booleans" do
    source <<-EOF
      (f ?x) = (true)
      f 10 && put success
    EOF

    result 'success'
  end
end
