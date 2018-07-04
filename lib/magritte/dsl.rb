module Magritte
  module DSL
    def spawn(env={}, &b)
      env = env.dup
      env[:$0] ||= Channel.new
      env[:$1] ||= Channel.new
      Command.new(env, &b).start
    end

    def spawn_loop(env={}, &b)
      spawn(env) do
        loop { b.call }
      end
    end

    def env
      ENV.current
    end

    def stdin
      env[:$0]
    end

    def stdout
      env[:$1]
    end

    def method_missing(m, *a, &b)
      if env.key?(m.to_s)
        env[m.to_s]
      else
        super
      end
    end
  end
end
