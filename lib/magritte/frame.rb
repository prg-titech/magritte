module Magritte
  class Frame
    attr_reader :env
    def initialize(env, p)
      @env = env
      @proc = p
      @compensations = []
    end

    def compensate(status)
      @compensations.each(&:run)
      unregister_channels
    end

    def checkpoint
      @compensations.each(&:run_checkpoint)
      unregister_channels
    end

    def add_compensation(comp)
      @compensations << comp
    end

    def repr
      "f"
    end

    def inspect
      "#<Frame #{repr}>"
    end

    def thread
      @proc.thread
    end

    def open_channels
      @env.each_input { |c| c.add_reader(self) }
      @env.each_output { |c| c.add_writer(self) }
    end

  private
    def unregister_channels
      PRINTER.p :unregister_channels => [@env.own_inputs, @env.own_outputs]
      @env.each_input { |c| c.remove_reader(self) }
      @env.each_output { |c| c.remove_writer(self) }
    end
  end
end
