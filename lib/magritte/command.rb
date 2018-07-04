module Magritte
  class Command
    attr_reader :env, :thread, :result
    def initialize(&b)
      @block = b
      @result = nil
    end

    class DSL
      def initialize(env={})
        @env = env || {}
      end

      def stdin; env[:$0]; end
      def stdout; env[:$1]; end

      def put(*els)
        els.each(&stdout.method(:put))
      end

      def get
        stdin.take
      end

    end

    def spawn(env)
      run_proc = proc do
        begin
          @result = env.instance_eval(&@block)
        ensure
          cleanup!
        end
      end

      Proc.new(Thread.new(&run_proc), env)
    end

    def kill!
      return if @shutting_down
      @shutting_down = true

      PRINTER.p :kill => @thread
      @thread.kill
      cleanup!
    end

    def cleanup!
      p :cleanup => env
      env.keys.map(&:to_s).grep(/^[$]\d+/).each do |chname|
        env[chname.to_sym].kill!
      end
    end

    def alive?
      @thread.alive?
    end

    def dead?
      !alive?
    end

    include Enumerable
    def each(&b)
      loop do
        yield read
      end
    rescue FiberError
      self
    end

    def read
      env[:$1].get
    end

    def pipe(new_env={}, &b)
      new_env = new_env.merge(:$0 => env[:$1])
      new_env[:$1] ||= Channel.new
      Command.new(new_env, &b).start
    end

    def put(*els)
      els.each { |e| env[:$1].put(e, self) }
      nil
    end

    def get
      env[:$0].get(self)
    end
  end
end
