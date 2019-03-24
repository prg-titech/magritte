interpret_spec "compensations" do
  interpret "unconditional checkpoint" do
    source <<-EOF
      exec (=>
        put 1 %%! put 2
        put 3
      )
    EOF

    results %w(1 3 2)
  end

  interpret "interrupts" do
    source <<-EOF
      c = (make-channel)
      exec (=> (
        put 1 %% (put comp > %c)
        put 2 3 4 5 6
      )) | take 2
      get < $c
    EOF

    results %w(1 2 comp)
  end

  interpret "interrupts on redirections" do
    source <<-EOF
      c = (make-channel)
      & put 1 2 3 > $c
      drain < $c
      (dr) = (put (get); dr)
      dr < $c

      # we never get here, because we get
      # interrupted by the above
      put 4
    EOF

    results %w(1 2 3)
  end

  interpret "get masking" do
    source <<-EOF
      c = (make-channel)
      & put 1 > $c
      get < $c
      get < $c

      # we never get here, because we get interrupted
      # by the above
      put 4
    EOF

    results %w(1)
  end

  interpret "the bug" do
    source <<-EOF
      c = (make-channel)
      (f) = (
        & put 1 > $c
        put 2
      )

      x = (f)

      get < $c
      put $x
    EOF

    results %w(1 2)
  end
end
