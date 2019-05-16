interpret_spec "basic functionality" do
  interpret "basic.mag" do
    source <<-EOF
      example = (load example/basic.mag)
      %example!f
    EOF

    results %w(10)
  end

  interpret "server.mag" do
    source <<-EOF
      example = (load example/server.mag)
      %example!__main__
    EOF

    results ["hello world"]
  end
end
