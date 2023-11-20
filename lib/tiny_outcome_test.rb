require 'minitest/autorun'
require_relative './tiny_outcome'

class TestTinyOutcome < Minitest::Test
  def setup
    @outcome = TinyOutcome.new(500, 100)
  end

  def test_init
    assert_equal [0] * @outcome.precision, @outcome.value
    assert_equal 500, @outcome.precision
    assert_equal 0, @outcome.warmth
    assert_equal 100, @outcome.warmup
    assert_equal 0, @outcome.samples
  end

  def test_add_samples
    assert_equal 0, @outcome.one_count

    @outcome << 1
    assert_equal [1] + ([0] * (@outcome.precision - 1)), @outcome.value
    assert_equal 500, @outcome.precision
    assert_equal 1, @outcome.warmth
    assert_equal 100, @outcome.warmup
    assert_equal 1, @outcome.samples
    assert_equal 1.0, @outcome.probability
    assert_equal 1, @outcome.one_count
    refute @outcome.warm?
    assert @outcome.cold?
    refute @outcome.full?
    assert @outcome.winner_at?(0.66)

    4.times { @outcome << 1 }
    5.times { @outcome << 0 }
    assert_equal 992, @outcome.numeric_value
    assert_equal 500, @outcome.precision
    assert_equal 10, @outcome.warmth
    assert_equal 100, @outcome.warmup
    assert_equal 10, @outcome.samples
    assert_equal 0.5, @outcome.probability
    assert_equal 5, @outcome.one_count
    refute @outcome.warm?
    assert @outcome.cold?
    refute @outcome.full?
    refute @outcome.winner_at?(0.66)

    @outcome << 1
    assert_equal 1985, @outcome.numeric_value
    assert_equal 500, @outcome.precision
    assert_equal 11, @outcome.warmth
    assert_equal 100, @outcome.warmup
    assert_equal 11, @outcome.samples
    assert_in_delta 0.545454, @outcome.probability
    assert_equal 6, @outcome.one_count
    refute @outcome.warm?
    assert @outcome.cold?
    refute @outcome.full?
    refute @outcome.winner_at?(0.66)

    488.times { @outcome << rand(2) }
    assert_equal 499, @outcome.samples
    assert @outcome.warm?
    refute @outcome.cold?
    refute @outcome.full?

    @outcome << rand(2)
    assert_equal 500, @outcome.samples
    assert @outcome.warm?
    refute @outcome.cold?
    assert @outcome.full?

    @outcome << rand(2)
    assert_equal 500, @outcome.samples
    assert @outcome.warm?
    refute @outcome.cold?
    assert @outcome.full?

    prev_one_count = @outcome.one_count
    @outcome << 1
    assert_equal 500, @outcome.samples
    assert_equal prev_one_count, @outcome.one_count # hasn't changed, because we're adding a 1 while pushing out a 1

    prev_one_count = @outcome.one_count
    @outcome << 0
    assert_equal 500, @outcome.samples
    assert_equal prev_one_count - 1, @outcome.one_count # reduced by one, because we're adding a 0 while pushing out a 1
  end

  def test_full_value_with_bit_rotation
    refute @outcome.full?
    assert_equal 0, @outcome.one_count

    500.times { @outcome << 1 }
    assert @outcome.full?
    assert_equal 2**500 - 1, @outcome.numeric_value

    @outcome << 0
    assert @outcome.full?
    assert_equal 2**500 - 2, @outcome.numeric_value

    @outcome << 0
    assert @outcome.full?
    assert_equal 2**500 - 4, @outcome.numeric_value

    @outcome << 1
    assert @outcome.full?
    assert_equal 2**500 - 7, @outcome.numeric_value
  end

  def test_min
    assert_equal 1.0, @outcome.min # initial, memoized value
    @outcome.update_stats!

    @outcome << 1
    @outcome << 0
    @outcome.update_stats!
    assert_equal 0.5, @outcome.min

    @outcome << 0
    @outcome.update_stats!
    assert_in_epsilon 0.3334, @outcome.min

    # fill up past the warmth amount
    [0, 1].cycle.each(100){|i| @outcome << i }
    @outcome.update_stats!
    assert_equal(203, @outcome.samples)
    assert_in_epsilon 0.49, @outcome.min

    # fill up past the total precision
    [0, 1].cycle.each(200){|i| @outcome << i }
    @outcome.update_stats!
    assert_equal(500, @outcome.samples)
    assert_in_epsilon 0.5, @outcome.min

    # fill with dropping trend
    [0, 0, 1].cycle.each(200){|i| @outcome << i }
    @outcome.update_stats!
    assert_equal(500, @outcome.samples)
    assert_in_epsilon 0.33, @outcome.min

    # fill with ascending trend
    [1, 0, 1].cycle.each(200){|i| @outcome << i }
    @outcome.update_stats!
    assert_equal(500, @outcome.samples)
    assert_in_epsilon 0.66, @outcome.min
  end

  def test_max
    assert_equal 0.0, @outcome.max # initial, memoized value
    @outcome.update_stats!

    @outcome << 1
    @outcome << 0
    @outcome << 1
    @outcome.update_stats!
    assert_in_epsilon 0.6667, @outcome.max

    @outcome << 0
    @outcome.update_stats!
    assert_in_epsilon 0.5, @outcome.max

    # fill up past the warmth amount
    [0, 1].cycle.each(100){|i| @outcome << i }
    @outcome.update_stats!
    assert_equal(204, @outcome.samples)
    assert_in_epsilon 0.5, @outcome.max

    # fill up past the total precision
    [0, 1].cycle.each(200){|i| @outcome << i }
    @outcome.update_stats!
    assert_equal(500, @outcome.samples)
    assert_in_epsilon 0.5, @outcome.max

    # fill with dropping trend
    [0, 0, 1].cycle.each(200){|i| @outcome << i }
    @outcome.update_stats!
    assert_equal(500, @outcome.samples)
    assert_in_epsilon 0.34, @outcome.max

    # fill with ascending trend
    [1, 0, 1].cycle.each(200){|i| @outcome << i }
    @outcome.update_stats!
    assert_equal(500, @outcome.samples)
    assert_in_epsilon 0.67, @outcome.max
  end

  def test_avg
    assert_equal 0.0, @outcome.avg # initial, memoized value
    @outcome.update_stats!

    @outcome << 1
    @outcome << 0
    @outcome << 1
    @outcome.update_stats!
    assert_in_epsilon 0.6667, @outcome.avg

    @outcome << 0
    @outcome.update_stats!
    assert_in_epsilon 0.5, @outcome.avg

    @outcome << 1
    @outcome.update_stats!
    assert_in_epsilon 0.6, @outcome.avg

    # fill up past the warmth amount
    [0, 1].cycle.each(100){|i| @outcome << i }
    @outcome.update_stats!
    assert_equal(205, @outcome.samples)
    assert_in_epsilon 0.5, @outcome.avg

    # fill up past the total precision
    [0, 1].cycle.each(200){|i| @outcome << i }
    @outcome.update_stats!
    assert_equal(500, @outcome.samples)
    assert_in_epsilon 0.5, @outcome.avg

    # fill with dropping trend
    [0, 0, 1].cycle.each(200){|i| @outcome << i }
    @outcome.update_stats!
    assert_equal(500, @outcome.samples)
    assert_in_epsilon 0.3334, @outcome.avg

    # fill with ascending trend
    [1, 0, 1].cycle.each(200){|i| @outcome << i }
    @outcome.update_stats!
    assert_equal(500, @outcome.samples)
    assert_in_epsilon 0.6667, @outcome.avg
  end
end
