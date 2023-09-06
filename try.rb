#!/usr/bin/env ruby

require_relative 'lib/async'
require_relative 'lib/async/queue'
require_relative 'lib/async/barrier'


Async do
  barrier = Async::Barrier.new
  barrier.async { sleep 0.1; raise 'ups'}
  barrier.async { sleep 2 }
  

  barrier.wait(fail_fast: false)
  puts 'done'
rescue Async::BarrierError => e
	puts "Barrier error: #{e} due to #{e.task.result.inspect}"
ensure
  barrier.stop
end

# barrier should abort and re-raise as soon as any task fails - fan out and fail early

# it's not clear how to close the queue to indicate no more jobs will be added
# Allow queue to be used for task finished

# The best way to implement this, is for the task to notify the barrier that it's done - success or failure, and for Barrier#wait to wait on that condition. We can make a few small changes to make this more ergonomic: #276

# Queue was previously a sub-class of Notification,
# now instead it takes a Notification in the initializer:

# - def initialize(parent: nil)
# + def initialize(parent: nil, available: Notification.new)

# it calls @available.signal when items are enqueue
# it calls @available.wait when items are dequeued

# this means that someone outside the queue can call available.signal(item), which will then be returned
# to those waiting to dequeue items.

# someone outside can also call available.wait and will be informed whenever items are enqueued.