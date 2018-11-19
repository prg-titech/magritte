module HasAbstract
  def abstract(*a)
    let(*a) { raise "abstract: #{a.map(&:inspect).join(', ')}" }
  end
end

Minitest::Spec.send(:extend, HasAbstract)
