module DanglingThreads
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
end
