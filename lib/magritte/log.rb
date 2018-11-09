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

    def current_log
      Thread.current[:magritte_log] ||= []
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
      a.each { |l| current_log << l }
    end

    def puts(*a)
      with_file { |f| f.puts(*a) }
      a.each { |l| current_log << l }
    end
  end

  PRINTER = case ENV['MAGRITTE_DEBUG']
  when nil, ""
    NullPrinter.new
  when 'log'
    Dir.mkdir("./tmp/log/#{$$}")
    LogPrinter.new("./tmp/log/#{$$}")
  else
    Printer.new
  end
end
