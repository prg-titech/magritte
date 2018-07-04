module Magritte
  class Pipeline
    # linear only for now
    def initialize(commands)
      @commands = commands
    end

    def spawn(env)
      @commands.zip(environments_for(env), &:spawn).wait
    end

    def environments_for(env)
      return enum_for(self, env) unless block_given?

      yield env.with(:$1 => Channel.new)

      (@commands.size - 2).times do
        yield env.with(:$0 => envs[-1].stdout, :$1 => Channel.new)
      end

      yield env.with_mut(:$0 => envs[-1].stdout)
    end
  end
end
