require 'method_profiler/report'

require 'benchmark'

module MethodProfiler
  # Observes an object, keeping track of all its method calls and the wall clock
  # time spent executing them.
  #
  class Profiler
    # Initializes a new {Profiler}. Wraps all methods in the object and its singleton
    # class with profiling code.
    #
    # @param [Object] obj The object to observe.
    #
    def initialize(obj)
      @obj = obj
      @data = Hash.new { |h, k| h[k] = [] }
      @observing = true

      wrap_methods_with_profiling
    end

    # Generates a report object with all the data collected so far bay the profiler. This report
    # can be displayed in various ways. See {Report}.
    #
    # @return [Report] A new report with all the data the profiler has collected.
    #
    def report
      Report.new(final_data, @obj.name)
    end

    def is_observing
      @observing
    end

    def start
      @observing = true
    end

    def stop
      @observing = false
    end

    def get_data
      final_data
    end

    private

    def wrap_methods_with_profiling
      profiler = self

      [
        { object: @obj.singleton_class, methods: @obj.methods(false), private: false, singleton: true },
        { object: @obj, methods: @obj.instance_methods(false), private: false },
        { object: @obj, methods: @obj.private_instance_methods(false), private: true }
      ].each do |group|
        group[:object].module_eval do
          group[:methods].each do |method|
            define_method("#{method}_with_profiling") do |*args, &block|
              call_without = lambda { send("#{method}_without_profiling", *args, &block) }
              if profiler.is_observing
                profiler.send(:profile, method, singleton: group[:singleton], myclass: self.class) do
                  call_without.call
                end
              else
                call_without.call
              end
            end

            alias_method "#{method}_without_profiling", method
            alias_method method, "#{method}_with_profiling"

            private "#{method}_with_profiling" if group[:private]
          end
        end
      end
    end

    def profile(method, options = {}, &block)
      klass = (options[:myclass] || "").to_s
      method_name = klass + (options[:singleton] ? ".#{method}" : "##{method}")
      elapsed_time, result = benchmark(block)
      elapsed_time = elapsed_time.to_s.match(/\(\s*([^\)]+)\)/)[1].to_f
      @data[method_name] << elapsed_time
      result
    end

    def final_data
      results = []

      @data.each do |method, records|
        total_calls = records.size
        total_time = records.reduce(:+)
        average = total_time / total_calls
        results << {
          method: method,
          min: records.min,
          max: records.max,
          average: average,
          total_time: total_time,
          total_calls: total_calls,
        }
      end

      results
    end

    def benchmark(block_to_benchmark)
      result = nil
      elapsed_time = Benchmark.measure { result = block_to_benchmark.call }
      return elapsed_time, result
    end
  end
end
