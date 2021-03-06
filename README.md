# !!! NOTE !!!
# It was merged into official

===========================

# mruby-enumerator

Enumerator in mruby

## Synopsis

```ruby
fib = Enumerator.new do |y|
  a = b = 1
  loop do
    y << a
    a, b = b, a + b
  end
end
p fib.take(10) #=> [1,1,2,3,5,8,13,21,34,55]

[10,20,30].each.with_index do |i, index|
  p [i,index] #=> [10,0], [20,1], [30,1]
end
```

## new Defines

- class Enumerator
- class Enumerator::Generator
- class Enumerator::Yielder
- class StopIteration < IndexError
- method Kernel#to_enum
- method Kernel#enum_for

## Redefines

- method Kernel#loop
- method Integral#times
- method Array#each
- method Hash#each
- method Range#each

## How to add Enumerator with Existing methods

```
class Some
  def each
    # add this line return Enumerator object unless block given.
    # arguments first is self, second is this method name symbol.
    return Enumerator.new self, :each unless block_given?

    # old code is OK as it is.
    [1,2,3].each do |i|
      yield i
    end
  end
end
```

## Installation

### use github repository

Write in /mruby/build_config.rb

```ruby
MRuby::Build.new do |conf|
  conf.gem :github => 'ksss/mruby-enumerator', :branch => 'master'
end
```

### or use mgem

```
mgem add mruby-enumerator
```

### build

and exec in your /mruby.

```
rake clean
rake
rake test
```

## License

MIT

## See also

[http://ruby-doc.org/core-1.9.3/Enumerator.html](http://ruby-doc.org/core-1.9.3/Enumerator.html)
