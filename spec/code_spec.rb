describe Magritte::Code do
  def with_no_dangling_threads(&b)
    orig_threads = Thread.list
    out = yield

    begin
      dangling = Thread.list - orig_threads

      assert { dangling.empty? }
      out
    rescue Minitest::Assertion
      retry_count ||= 0
      retry_count += 1
      raise if retry_count > 20

      # yield the current thread to allow other threads to be cleaned up
      # since sometimes it takes a bit of time for thread.raise to actually
      # kill the thread and there's no way to wait for it :\
      sleep 0.1

      retry
    end
  end

  let(:output) { with_no_dangling_threads { code.spawn_collect } }

  abstract(:code)
  def self.code(&b)
    let(:code) { Magritte::Code.new { Magritte::Code::DSL.instance_eval(&b) } }
  end

  after { Magritte::PRINTER.p output: output }

  describe 'a single pipe' do
    # ( put 1 | put (5 + (get)) ); put 10
    code do
      s { put 1 }.p { put(5 + get) }.call
      put 10
    end

    it 'successfully pipes' do
      assert { output == [6, 10] }
    end
  end

  describe 'multiple pipes' do
    # (put 1; put 2) | add (get) (get) | mul 2 (get)
    code do
      s { put 1; put 2 }.p { put(get + get) }.p { put(get * 2) }.call

      put 10
    end

    it 'successfully pipes' do
      assert { output == [6, 10] }
    end
  end

  describe 'cleanup write end' do
    # count-from 0 | take 3
    code do
      s { for_ (0..Infinity) }
        .p { put get; put get; put get }.call
    end

    it 'returns normally' do
      assert { output == [0, 1, 2] }
    end
  end

  describe 'cleanup read end' do
    # for [0 1 2 3] | map [mul 2]
    code do
      s { for_ (0..3) }
        .p { map { |x| x * 2 } }.call

      put 10
    end

    it 'returns normally' do
      assert { output == [0, 2, 4, 6, 10] }
    end
  end

  describe 'regular looping' do
    code do
      s { for_ (0..3) }
        .p { loop { put (get * 2) } }.call

      raise "never reached"
    end

    it 'interrupts the parent process' do
      assert { output == [0, 2, 4, 6] }
    end
  end

  describe 'multiple writers' do
    code do
      # c = (make-channel)
      # & (put 2; put 4; put 6) > $c
      # & (put 1; put 3; put 5) > $c
      # drain < $c
      c = Magritte::Channel.new
      s { put 2; put 4; put 6 }.into(c).go
      s { put 1; put 3; put 5 }.into(c).go

      s { drain }.from(c).call
    end

    it 'combines the outputs' do
      assert { output.size == 6 }
      assert { output.select(&:even?) == [2, 4, 6] }
      assert { output.select(&:odd?) == [1, 3, 5] }
    end
  end

  describe 'multiple writers to a Collector' do
    code do
      p1 = s { put 2; put 4; put 6 }.go
      p2 = s { put 1; put 3; put 5 }.go

      p1.join
      p2.join
    end

    it 'combines the outputs' do
      assert { output.size == 6 }
      assert { output.select(&:even?) == [2, 4, 6] }
      assert { output.select(&:odd?) == [1, 3, 5] }
    end
  end

  describe 'multiple readers' do
    code do
      c = make_channel

      s {
        s { for_ (0..Infinity) }.into(c).go
        s { drain }.from(c).go
        s { drain }.from(c).call
      }.p { take 10 }.call
    end

    it 'does a thing' do
      assert { output.size == 10 }

      # no duplicates!
      assert { output.uniq.size == 10 }

      # there is a possibility that the 11th read from the counter
      # will beat the nth read from the counter to write into
      # the `take 10` process, in which case the number 10 will
      # replace the number n
      assert { ((0..10).to_a - output).size == 1 }
    end
  end

  describe 'multi pipe' do
    code do
      s { for_ (0...30) }.p {
        s { drain }.go
        s { drain }.go
        s { drain }.go
      }.p { take 30 }.call
    end

    it 'collects the outputs' do
      assert { output.sort == (0...30).to_a }
    end
  end
end
