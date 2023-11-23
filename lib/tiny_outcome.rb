# TinyOutcomes are used to track a history of binary outcomes to the specified
# precision. for example:
#   Outcome.new(128)  # tracks 128 historic outcomes
#
# when the number of samples added exceeds the number of samples to track, then
# the oldest sample is dropped automatically. in this way, a TinyOutcome that
# tracks 128 samples will start discarding its oldest sample as soon as the
# 129th sample is added.
#
# TinyOutcomes can also be cold, or warm. warm TinyOutcomes have received a
# minimum number of historic samples to be considered useful. see #initialize
# for more information on how warmth works.
#
# Usage:
#   o = TinyOutcome.new(
#         128,                                  precision of 128 samples
#         TinyOutcome::WARM_TWO_THIRDS          warms up at 2/3rs of precision
#       )
#   o.to_hash                                   convenient way to see what's up
#   87.times { o << rand(2) }
#
# to_s reveals how we're doing:
#   L10 1111000110 w 0.49 84/84::128/128
#
# this tells us that of the 128 precision capacity, we're currently warmed up
# because we have the minimum (at least 84 samples) to be considered warmed up
# (this is also indicated with the lowercase 'w').
class TinyOutcome
  attr_reader :precision,
              :samples,
              :warmth,
              :warmup,
              :probability,
              :one_count,
              :value,
              :min,
              :max,
              :avg

  WARM_FULL = :full
  WARM_TWO_THIRDS = :two_thirds
  WARM_HALF = :half
  WARM_ONE_THIRD = :one_third
  WARM_NONE = :none

  # precision: the number of historic samples you want to store
  # warmup: defaults to WARM_FULL, lets the user specify how many samples we
  #   need in order to consider this Outcome tracker "warm", i.e. it has enough
  #   samples that we can trust the probability output
  def initialize(precision, warmup=WARM_FULL)
    @precision = precision
    @probability = 0.0
    @one_count = 0
    @samples = 0
    @min = 1.0
    @max = 0.0
    @avg = 0.0
    @warmth = 0
    @value = [0] * @precision
    @value_index = 0
    @warmup = case warmup
              when WARM_FULL        then precision
              when WARM_TWO_THIRDS  then (precision / 3) * 2
              when WARM_HALF        then precision / 2
              when WARM_ONE_THIRD   then precision / 3
              when WARM_NONE        then 0
              else
                raise "Invalid warmup: #{warmup.inspect}" if (!warmup.is_a?(Integer) || warmup < 1)
                warmup
              end
  end

  # returns the array of collected samples of 1s and 0s
  def collected_samples
    (full? ? @value.rotate(@value_index) : @value)[..(samples-1)]
  end

  # converts the array of #collected_samples to a base-10 Integer
  def numeric_value
    collected_samples.join.to_i(2)
  end

  # add a sample to the historic outcomes
  def <<(sample)
    raise "Invalid sample: #{sample}" unless sample == 0 || sample == 1

    removing_one = full? && @value[(@value_index + 1) % @precision] == 1

    @value[@value_index] = sample
    @value_index = (@value_index + 1) % @precision
    @warmth += 1 unless warmth == warmup
    @samples += 1 unless full?

    # percentage of 1s out of the existing samples
    #
    #               number of 1s
    # probabilty = ---------------
    #               total samples
    @one_count -= 1 if removing_one
    @one_count += 1 if sample == 1
    @probability = @one_count / samples.to_f

    @value
  end

  # true if #probability is >= percentage
  # false otherwise
  def winner_at?(percentage)
    @probability >= percentage
  end

  # true if #probability is >= percentage
  # false otherwise
  def winner_at_lately?(percentage, max_samples)
    recent_samples = collected_samples.last(max_samples)
    recent_probability = recent_samples.count(1) / recent_samples.length.to_f
    recent_probability >= percentage
  end

  # true if we've received at least warmup number of samples
  # false otherwise
  def warm?
    warmth >= warmup
  end

  # the opposite of warm: a TinyOutcome can only be cold or warm
  def cold?
    !warm?
  end

  # true if we've received at least precision number of samples
  # false otherwise
  def full?
    samples == precision
  end

  # updates, and memoizes, the min/max/avg numbers. if you read the min/max/avg
  # attributes you are getting the MEMOIZED values.
  def update_stats!
    return if @samples == 0

    @min = 1.0
    @max = 0.0
    @avg = 0.0

    sum = 0.0
    raw = (full? ? @value.rotate(@value_index) : @value)[..(samples-1)]
    group_size = [@samples, 100].min
    num_groups = (@samples - group_size) + 1
    raw.each_cons(group_size) do |samples_group|
      num_ones = samples_group.count(1) / group_size.to_f
      sum += num_ones

      @min = num_ones if num_ones < @min
      @max = num_ones if num_ones > @max
    end

    @avg = sum / num_groups.to_f
  end

  # convenient way to see what's up
  def to_hash
    [:value,
     :samples,
     :warmth,
     :warmup,
     :warm?,
     :probability,
    ].each_with_object({}) do |attr, memo|
      memo[attr] = send(attr)
      memo
    end
  end

  # L10 = last 10 samples
  def to_s
    max_backward = [value.to_s(2).length, 10].min
    "L10 #{value.to_s(2)[-max_backward..-1].rjust(10, '?')} #{warm? ? 'W' : 'c'} #{'%.2f' % probability} #{warmth}/#{warmup}::#{samples}/#{precision}"
  end
end
