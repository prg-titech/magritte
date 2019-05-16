module Magritte
  module Runtime
    class Scheduler
      class Done < StandardError
      end

      class ProcDone < StandardError
      end

      class Deadlock < StandardError
      end

      attr_reader :logger
      def initialize(opts={})
        @channels = []
        @procs = []
        @logger = opts.fetch(:logger) { [] }
      end

      def log(msg)
        @logger << msg + "\n"
      end

      def new_collector(frame)
        c = Collector.new(self, frame)
        c.id = @channels.size
        @channels << c
        c
      end

      def new_channel
        c = Channel.new(self)
        c.id = @channels.size
        @channels << c
        c
      end

      def register_channels(frame)
        frame.env.each_output do |c|
          c.add_writer(frame)
        end

        frame.env.each_input do |c|
          c.add_reader(frame)
        end
      end

      def unregister_channels(frame)
        frame.env.each_output do |c|
          log "rm_writer(#{c.repr}, #{frame.repr})"
          c.rm_writer(frame)
          log "-> #{c.repr}"
        end

        frame.env.each_input do |c|
          log "rm_reader(#{c.repr}, #{frame.repr})"
          c.rm_reader(frame)
          log "-> #{c.repr}"
        end
      end

      def wait_for_close(proc_, c)
        if c.closed?
          puts "wait_for_close(#{proc_.pid}, #{c.inspect}) skip!"
        else
          proc_.state = :waiting
          c.wait_for_close(proc_)
          puts "wait_for_close(#{proc_.pid}, #{c.inspect}) waiting!"
        end
      end

      def run
        step while @procs.any?
      rescue Done
        @procs
      end

      def step
        moved = 0
        waiting = 0


        log ""
        log "//////// step phase ///////////"
        @procs.each do |p|
          next unless p

          case p.state
          when :waiting then waiting += 1; next
          when :done then next
          else moved += 1
          end

          moved += 1

          new_state = p.step
        end

        log "[#{@procs.map { |p| p ? "#{p.pid}:#{p.state}" : '_' }.join(' ')}]"

        log "///// resolve phase //////"
        @channels.each(&:resolve!)

        raise Deadlock if moved == 0 and waiting > 0
        raise Done if moved == 0

        moved
      end

      def spawn(ast, env)
        proc_ = Proc.new(self, ast)

        proc_.state = :running

        free_pid = nil
        @procs.each_with_index do |p, i|
          if p.nil?
            free_pid = i
            break
          end
        end

        if free_pid
          proc_.pid = free_pid
          @procs[free_pid] = proc_
        else
          proc_.pid = @procs.size
          @procs << proc_
        end

        proc_.frame(env)

        proc_
      end

      def read
        env.stdin.read(self, @layers.last)
      end

      def spawn_root(ast, env, out=[])
        c = new_collector(out)
        spawn(ast, env.extend([], [c]))
        c
      end

      def terminate(proc_)
        proc_.state = :terminated
        @procs[proc_.pid] = nil
      end
    end
  end
end
