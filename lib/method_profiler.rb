require 'method_profiler/profiler'

# {MethodProfiler} collects performance information about the methods
# in your objects and creates reports to help you identify slow methods.
#
module MethodProfiler
  # Create a new {MethodProfiler::Profiler} which will observe all method calls
  # on the given object. This is a convenience method and has the same effect
  # as {MethodProfiler::Profiler#initialize}.
  #
  # @param [Object] obj The object to observe.
  # @return [MethodProfiler::Profiler] A new profiler.
  #
  def self.observe(obj)
    Thread.current[:observing] = true
    (all_profilers[obj] ||= Profiler.new(obj)).start
  end

  def self.all_profilers
    Thread.current[:profilers] ||= {}
  end

  def self.stop_all
    all_profilers.values.each(&:stop)
  end

  def self.clear
    stop_all
    all_profilers.clear
  end

  def self.get_report
    all_data = all_profilers.values.collect(&:get_data).flatten
    Report.new(all_data, "all").to_a
  end
end
