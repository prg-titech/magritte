require 'thread'
require 'set'

# $... means global variable

$mutex = Mutex.new
$readers = Set.new
$writers = Set.new
$block_type = :none
$block_set = []
$open = true

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
    if $block_type == :write
      $block_set.delete(t)
    end

    cleanup_from(t, $writers)
  end

  to_close.each { |thread| thread.raise(Interrupt.new) }
end

def rm_reader(t)
  to_close = $mutex.synchronize do
    if $block_type == :read
      $block_set.delete(t)
    end

    cleanup_from(t, $readers)
  end

  to_close.each { |thread| thread.raise(Interrupt.new) }
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
    return to_clean
  else
    return Set.new
  end
end

def read(t)
  $mutex.synchronize do
    if not $open
      t.raise(Interrupt.new)
    end

    case $block_type
    when :none, :read
      # in this case there are no waiting write threads,
      # so this process must block.
      $block_type = :read
      $block_set << t

      # this releases the mutex and sleeps in one atomic action.
      # on wakeup, it will acquire the mutex again (and immediately
      # release it at the end of the synchronize block).
      $mutex.sleep
    when :write
      # in this case there are waiting write threads,
      # so we do *not* block, and instead wake up a
      # write thread.
      write_thread = $block_set.shift

      if $block_set.empty?
        $block_type = :none
      end

      # the square brackets on threads set thread-local variables.
      # i suspect that if these were replaced by global variables
      # then race conditions would be introduced.
      t[:read_value] = write_thread[:write_value]

      write_thread.run
    end
  end

  return t[:read_value]
end

def write(t, val)
  $mutex.synchronize do
    if not $open
      t.raise(Interrupt.new)
    end

    case $block_type
    when :none, :write
      $block_type = :write
      $block_set << t
      t[:write_value] = val
      $mutex.sleep
    when :read
      read_thread = $block_set.shift

      if $block_set.empty?
        $block_type = :none
      end

      read_thread[:read_value] = val

      read_thread.run
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
        $output_mutex.synchronize { $output << read(Thread.current) }
      end
    ensure
      rm_reader(Thread.current)
    end
  end
end

# produce all even numbers
spawn_producer!(0, 2)

# produce all odd numbers
spawn_producer!(1, 2)

consumer1 = spawn_consumer!
consumer2 = spawn_consumer!
consumer3 = spawn_consumer!

consumer1.join
consumer2.join
consumer3.join

puts "output: #{$output.inspect}"
puts "live threads (should be exactly 1, in \"run\" state):"
puts Thread.list.map(&:inspect)
