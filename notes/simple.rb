require 'thread'
require 'set'

$exception = StandardError.new

# $... means global variable

$mutex = Mutex.new
$readers = Set.new
$writers = Set.new
$block_type = :none
$open = true

# an element of the block set will look like:
# [thread, value]
# where value is either the value to be written (if writers are blocked)
# or a ref to receive the value (if readers are blocked)
$block_set = []


$output_mutex = Mutex.new
$output = []

def add_reader(t)
  $mutex.synchronize { $readers << t }
end

def add_writer(t)
  $mutex.synchronize { $writers << t }
end

def rm_reader(t)
  to_close = $mutex.synchronize do
    if $block_type == :read
      $block_set.reject! { |b| b[0] == t }
    end

    cleanup_from(t, $readers)
  end

  to_close.each { |thread| thread.raise($exception) }
end

def rm_writer(t)
  to_close = $mutex.synchronize do
    if $block_type == :write
      $block_set.reject! { |b| b[0] == t }
    end

    cleanup_from(t, $writers)
  end

  to_close.each { |thread| thread.raise($exception) }
end

def cleanup_from(t, set)
  if not $open
    # no threads to clean up
    return Set.new
  end

  set.delete(t)

  # if the registered set becomes empty,
  # close the channel.
  if set.empty?
    $open = false
    to_clean = $block_set.dup
    $block_set.clear
    return to_clean.map { |b| b[0] }
  else
    return Set.new
  end
end

def read(t)
  $mutex.synchronize do
    if not $open
      t.raise($exception)
    end

    case $block_type
    when :none, :read
      # in this case there are no waiting write threads,
      # so this process must block.
      $block_type = :read
      ref = [t, nil]
      $block_set << ref

      # this releases the mutex and sleeps in one atomic action.
      # on wakeup, it will acquire the mutex again (and immediately
      # release it at the end of the synchronize block).
      $mutex.sleep

      return ref[1]
    when :write
      # in this case there are waiting write threads,
      # so we do *not* block, and instead wake up a
      # write thread.
      write_thread, written_value = $block_set.shift

      if $block_set.empty?
        $block_type = :none
      end

      write_thread.run

      return written_value
    end
  end
end

def write(t, val)
  $mutex.synchronize do
    if not $open
      t.raise($exception)
    end

    case $block_type
    when :none, :write
      $block_type = :write
      $block_set << [t, val]
      $mutex.sleep
    when :read
      read_ref = $block_set.shift

      if $block_set.empty?
        $block_type = :none
      end

      # here we mutate the ref from the block_set
      # before waking it up again, so that it can receive the
      # value when it wakes up. we guarantee that at the end
      # of the synchronize block in #read, this value is set.
      read_ref[1] = val

      read_ref[0].run
    end
  end
end

def spawn_producer!(init=0, step=1)
  Thread.new do
    begin
      add_writer(Thread.current)
      i = init
      loop do
        write(Thread.current, i)
        i += step
      end
    ensure
      rm_writer(Thread.current)
    end
  end
end

def spawn_consumer!
  Thread.new do
    begin
      add_reader(Thread.current)
      10.times do
        # yield the thread randomly to increase the chance of races
        sleep(rand / 10)
        $output_mutex.synchronize { $output << read(Thread.current) }
      end
    ensure
      rm_reader(Thread.current)
    end
  end
end

# produce all even numbers
producer1 = spawn_producer!(0, 2)

# produce all odd numbers
producer2 = spawn_producer!(1, 2)

consumer1 = spawn_consumer!
consumer2 = spawn_consumer!
consumer3 = spawn_consumer!

consumer1.join
consumer2.join
consumer3.join

# the "rescue"s are necessary here because .join will re-raise the Inter
# exception in our thread
producer1.join rescue nil
producer2.join rescue nil

puts "output: #{$output.inspect}"
puts "live threads (should be exactly 1, in \"run\" state):"
puts Thread.list.map(&:inspect)
