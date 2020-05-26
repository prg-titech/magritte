module Rescuing
  def rescuing(type=Exception)
    yield
    nil
  rescue type => e
    e
  end
end

Object.send(:include, Rescuing)
