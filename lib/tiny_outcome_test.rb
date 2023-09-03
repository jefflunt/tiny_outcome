require 'minitest/autorun'
require_relative './tiny_outcome'

class TestTinyOutcome < Minitest::Test
  def setup
    @outcome = TinyOutcome.new(500, 100)
  end

  def test_init
    assert_equal 0, @outcome.value
    assert_equal 500, @outcome.precision
    assert_equal 0, @outcome.warmth
    assert_equal 100, @outcome.warmup
    assert_equal 0, @outcome.samples
  end

  def test_add_samples
    @outcome << 1
    assert_equal 1, @outcome.value
    assert_equal 500, @outcome.precision
    assert_equal 1, @outcome.warmth
    assert_equal 100, @outcome.warmup
    assert_equal 1, @outcome.samples
    assert_equal 1.0, @outcome.probability
    refute @outcome.warm?
    assert @outcome.cold?
    refute @outcome.full?

    4.times { @outcome << 1 }
    5.times { @outcome << 0 }
    assert_equal 992, @outcome.value
    assert_equal 500, @outcome.precision
    assert_equal 10, @outcome.warmth
    assert_equal 100, @outcome.warmup
    assert_equal 10, @outcome.samples
    assert_equal 0.5, @outcome.probability
    refute @outcome.warm?
    assert @outcome.cold?
    refute @outcome.full?

    @outcome << 1
    assert_equal 1985, @outcome.value
    assert_equal 500, @outcome.precision
    assert_equal 11, @outcome.warmth
    assert_equal 100, @outcome.warmup
    assert_equal 11, @outcome.samples
    assert_in_delta 0.545454, @outcome.probability
    refute @outcome.warm?
    assert @outcome.cold?
    refute @outcome.full?

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
  end
end
