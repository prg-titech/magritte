require 'thread'

module Magritte
  class Printer
    def initialize
      @mutex = Mutex.new
    end

    def puts(*a)
      @mutex.synchronize { ::Kernel.puts(*a) }
    end

    def p(*a)
      @mutex.synchronize { ::Kernel.p(*a) }
    end
  end

  class NullPrinter < Printer
    def puts(*); end
    def p(*); end
  end

  class LogPrinter
    def initialize(prefix)
      @prefix = prefix
    end

    def fname
      Thread.current.inspect =~ /0x\h+/
      $&
    end

    def with_file(&b)
      File.open("#{@prefix}/#{fname}", 'a', &b)
    end

    def p(*a)
       with_file { |f| f << a.map(&:inspect).join(' / ') << "\n" }
    end

    def puts(*a)
      with_file { |f| f.puts(*a) }
    end
  end

  if ENV['MAGRITTE_DEBUG']
    Dir.mkdir("./tmp/log/#{$$}")
    # PRINTER = LogPrinter.new("./tmp/log/#{$$}")
    PRINTER = Printer.new
  else
    PRINTER = NullPrinter.new
  end

  def self.reload!
    Object.send(:remove_const, :Magritte)
    load __FILE__
    self
  end

  LIB_DIR = File.dirname(__FILE__)
  load "#{LIB_DIR}/magritte/std.rb"
  load "#{LIB_DIR}/magritte/code.rb"
  load "#{LIB_DIR}/magritte/channel.rb"
  load "#{LIB_DIR}/magritte/proc.rb"
end
