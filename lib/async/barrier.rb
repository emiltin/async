# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.

require_relative 'list'
require_relative 'task'

module Async

	# Raised if a task in a barrier fails
	class BarrierError < StandardError
		attr_reader :task, :error
		def initialize(message = "task failed",task:)
			@task = task
			super(message)
		end
	end
	

		# A general purpose synchronisation primitive, which allows one task to wait for a number of other tasks to complete. It can be used in conjunction with {Semaphore}.
	#
	# @public Since `stable-v1`.
	class Barrier
		# Initialize the barrier.
		# @parameter parent [Task | Semaphore | Nil] The parent for holding any children tasks.
		# @public Since `stable-v1`.
		def initialize(parent: nil)
			@tasks = List.new
			@finished = Notification.new

			@parent = parent
		end
		
		class TaskNode < List::Node
			def initialize(task)
				@task = task
			end
			
			attr :task
		end
		
		private_constant :TaskNode
		
		# Number of tasks being held by the barrier.
		def size
			@tasks.size
		end
		
		# All tasks which have been invoked into the barrier.
		attr :tasks
		
		# Execute a child task and add it to the barrier.
		# @asynchronous Executes the given block concurrently.
		def async(*arguments, parent: (@parent or Task.current), finished: @finished, **options, &block)
			task = parent.async(*arguments, finished:, **options, &block)
			
			@tasks.append(TaskNode.new(task))
			
			return task
		end
		
		# Whether there are any tasks being held by the barrier.
		# @returns [Boolean]
		def empty?
			@tasks.empty?
		end
		
		# Wait for all tasks to complete. A task will be removed from the barrier whether if completes or fails.
		# @parameter fail_fast [Boolean] Whether re-raise as soon as any task fails
		def wait(fail_fast: true)
			until @tasks.empty?
				task = @finished.wait
				if fail_fast && task.failed?
					raise BarrierError.new("Failing fast", task: task)
				end
				remove(task)
			end
		end
		
		# Stop all tasks held by the barrier.
		# @asynchronous May wait for tasks to finish executing.
		def stop
			@tasks.each do |waiting|
				waiting.task.stop
			end
		end

		private

		# Remove node containing task
		# @parameter task [Task] Task to remove		
		def remove task
			return if task.alive?
			node = @tasks.each do |node| 
				if node.task == task
					@tasks.remove(node) 
					return true
				end
			end
			false
		end
	end
end
