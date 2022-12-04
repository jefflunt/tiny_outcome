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
#   L10 1111000110 coinflip 0.49 84/84::128/128
#
# this tells us that of the 128 precision capacity, we're currently warmed up
# because we have the minimum (at least 84 samples) to be considered warmed up.
# there's also a prediction here: that the outcome is essentially a coinflip.
# this is because the observed likelihood of an outcome of 1 is 49% in this
# example, well within the range of random chance. if we had a TinyOutcome with
# a precision of 10,000 we wouldn't necessarily consider 49% a true coinflip,
# but because we're trying to predict things within a relatively small sample
# size, we don't want to go all the way to that level of precision, it's more
# like just trying to win more than we lose.
class TinyOutcome
  attr_reader :precision,
              :samples,
              :warmth,
              :warmup,
              :value

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
    @samples = 0
    @warmth = 0
    @value = 0
    @warmup = case warmup
              when WARM_FULL        then precision
              when WARM_TWO_THIRDS  then (precision / 3) * 2
              when WARM_HALF        then precision / 2
              when WARM_ONE_THIRD   then precision / 3
              when WARM_NONE        then 0
              else
                raise "Invalid warmup: #{warmup.inspect}"
              end
  end

  # add a sample to the historic outcomes. the new sample is added to the
  # low-order bits. the new sample is literally left-shifted into the value. the
  # only reason this is a custom method is because some metadata needs to be
  # updated when a new sample is added
  def <<(sample)
    raise "Invalid sample: #{sample}" unless sample == 0 || sample == 1

    @value = ((value << 1) | sample) & (2**precision - 1)
    @warmth += 1 unless warmth == warmup
    @samples += 1 unless samples == precision

    value
  end

  # true if #probability is >= percentage
  # false otherwise
  def winner_at?(percentage)
    probability >= percentage
  end

  # float: 0.0-1.0
  # percentage of 1s out of the existing samples
  #
  #               number of 1s
  # probabilty = ---------------
  #               total samples
  def probability
    return -1 unless warm?
    value.to_s(2).count('1') / samples.to_f
  end

  # classifies the probability of the next outcome
  #
  # :cold - if this Outcome isn't yet warm
  # :highly_positive - greater than 95% chance that the next outcome will be a 1
  # :positive - greater than 90% chance the next outcome will be a 1
  # :coinflip - 50% chance (+/- 5%) that the next outcome will be a 1
  # :negative - less than 10% chance the next outcome will be a 1
  # :highly_negative - less than 5% chance the next outcome will be a 1
  # :weak - for all other outcomes
  def prediction
    return :cold unless warm?

    case probability
    when 0...0.05     then :disaster
    when 0.05...0.1   then :strongly_negative
    when 0.1...0.32   then :negative
    when 0.32..0.34   then :one_third
    when 0.34...0.48  then :weakly_negative
    when 0.48..0.52   then :coinflip
    when 0.52...0.65  then :weakly_positive
    when 0.65..0.67   then :two_thirds
    when 0.67..0.9    then :positive
    when 0.9...0.95   then :strongly_positive
    when 0.95..1.0    then :amazing
    end
  end

  # true if we've received at least warmup number of samples
  # false otherwise
  def warm?
    warmth == warmup
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

  # convenient way to see what's up
  def to_hash
    [:value,
     :samples,
     :warmth,
     :warmup,:warm?,
     :probability,
     :prediction,
    ].each_with_object({}) do |attr, memo|
      memo[attr] = send(attr)
      memo
    end
  end

  def to_s
    max_backward = [value.to_s(2).length, 10].min
    "L10 #{value.to_s(2)[-max_backward..-1].rjust(10, '?')} #{prediction} #{'%.2f' % probability} #{warmth}/#{warmup}::#{samples}/#{precision}"
  end
end
