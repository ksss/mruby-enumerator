#
# mruby-enumerator
# original: https://github.com/ruby/ruby/blob/trunk/enumerator.c
#

#
# Enumerator.new { |yielder| ... }
# Enumerator.new(obj, method = :each, *args)
#
# creates a new Enumerator object, which can be used as an Enumerable
#
# fib = Enumerator.new do |y|
#   a = b = 1
#   loop do
#     y << a
#     a, b = b, a + b
#   end
# end
#
# p fib.take(10) #=> [1,1,2,3,5,8,13,21,34,55]
#
class Enumerator
  include Enumerable

  class Generator
    def initialize &block
      raise TypeError, "wrong argument type #{self.class} (expected Proc)" unless block.kind_of? Proc

      @proc = block
    end

    def each *args, &block
      args.unshift Yielder.new &block
      @proc.call *args
    end
  end

  class Yielder
    def initialize &block
      raise LocalJumpError, "no block given" unless block_given?

      @proc = block
    end

    def yield *args
      @proc.call *args
    end

    def << *args
      self.yield *args
      self
    end
  end

  def initialize obj=nil, meth=:each, *argv, &block
    if block_given?
      obj = Generator.new &block
    else
      raise ArgumentError unless obj
    end

    @obj = obj
    @meth = meth
    @args = argv.dup
    @fib = nil
    @dst = nil
    @lookahead = nil
    @feedvalue = nil
    @stop_exc = false
  end
  attr_accessor :obj, :meth, :args, :fib
  private :obj, :meth, :args, :fib

  def initialize_copy obj
    raise TypeError, "can't copy type #{obj.class}" unless obj.kind_of? Enumerator
    raise TypeError, "can't copy execution context" if obj.fib
    @obj = obj.obj
    @meth = obj.meth
    @args = obj.args
    @fib = nil
    @lookahead = nil
    @feedvalue = nil
    self
  end

  def with_index offset=0
    return Enumerator.new self, :with_index, offset unless block_given?
    raise TypeError, "no implicit conversion of #{offset.class} into Integer" unless offset.respond_to?(:to_int)

    n = offset.to_int
    each do |i|
      yield [i,n]
      n += 1
    end
  end

  def each_with_index
    with_index 0
  end

  def with_object object
    return Enumerator.new self, :with_object, offset unless block_given?

    each do |i|
      yield [i,object]
    end
    object
  end

  def inspect
    return "#<#{self.class}: uninitialized>" unless @obj
    "#<#{self.class}: #{@obj}:#{@meth}>"
  end

  def each *argv, &block
    if 0 < argv.length
      obj = self.dup
      args = obj.args
      if !args.empty?
        args = args.dup
        args.concat argv
      else
        args = argv.dup
      end
      @args = args
    end
    return self unless block_given?
    @obj.__send__ @meth, *@args, &block
  end

  def next
    ary2sv next_values, false
  end

  def next_values
    if @lookahead
      vs = @lookahead
      @lookahead = nil
      return vs
    end
    raise @stop_exc if @stop_exc

    curr = Fiber.current

    if !@fib || !@fib.alive?
      @dst = curr
      @fib = Fiber.new do
        result = each do |*args|
          feedvalue = nil
          Fiber.yield args
          if @feedvalue
            feedvalue = @feedvalue
            @feedvalue = nil
          end
          feedvalue
        end
        @stop_exc = StopIteration.new "iteration reached an end"
        @stop_exc.result = result
        Fiber.yield nil
      end
      @lookahead = nil
    end

    vs = @fib.resume @curr
    if @stop_exc
      @fib = nil
      @dst = nil
      @lookahead = nil
      @feedvalue = nil
      raise @stop_exc
    end
    vs
  end

  def peek
    ary2sv peek_values, true
  end

  def peek_values
    if @lookahead.nil?
      @lookahead = next_values
    end
    @lookahead.dup
  end

  def rewind
    @obj.rewind if @obj.respond_to? :rewind
    @fib = nil
    @dst = nil
    @lookahead = nil
    @feedvalue = nil
    @stop_exc = false
    self
  end

  def feed v
    raise TypeError, "feed value already set" if @feedvalue
    @feedvalue = v
    nil
  end

  def ary2sv args, dup
    return args unless args.kind_of? Array

    case args.length
    when 0
      nil
    when 1
      args[0]
    else
      return args.dup if dup
      args
    end
  end
  private :ary2sv
end

class StopIteration < IndexError
  attr_accessor :result
end

module Kernel
  def to_enum meth=:each, *argv
    Enumerator.new self, meth, *argv
  end
  alias :enum_for :to_enum

  def loop
    while(true)
      yield
    end
  rescue => StopIteration
    return Enumerator.new self, :each unless block_given?
    nil
  end
end

module Integral
  def times &block
    return Enumerator.new self, :times unless block_given?
    i = 0
    while i < self
      block.call i
      i += 1
    end
    self
  end
end

class Array
  def each &block
    return Enumerator.new self, :each unless block_given?

    idx, length = -1, self.length-1
    while idx < length and length <= self.length and length = self.length-1
      elm = self[idx += 1]
      unless elm
        if elm == nil and length >= self.length
          break
        end
      end
      block.call(elm)
    end
    self
  end
end

class Hash
  def each &block
    return Enumerator.new self, :each unless block_given?

    self.keys.each { |k| block.call [k, self[k]] }
    self
  end
end

class Range
  def each &block
    return Enumerator.new self, :each unless block_given?

    val = self.first
    unless val.respond_to? :succ
      raise TypeError, "can't iterate"
    end

    last = self.last
    return self if (val <=> last) > 0

    while((val <=> last) < 0)
      block.call(val)
      val = val.succ
    end

    if not exclude_end? and (val <=> last) == 0
      block.call(val)
    end
    self
  end
end
