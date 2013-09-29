# Changelog

## Master

* Continue processing files even if a file has invalid syntax
* Fix a crash on source `variable::Const`
* Fix generating invalid code with here document followed by method

## v0.1.1

* Fix a bug where `be > 1` was converted into `be be > 1`

## v0.1.0

* Highlight source in console when warning conversion error
* Add `--no-color` option

## v0.0.10

* Support conversion of `at_least(0)`
* Add `-f` shorthand for `--force` option

## v0.0.9

* Use `--disable allow_to_receive` to disable conversion from `obj.should_receive(:foo).any_number_of_times` to `allow(obj).to receive(:foo)` (Previously it was `--disable expect_to_receive`)

## v0.0.8

* Support conversion from `not_to raise_error(SpecificErrorClass)` to `not_to raise_error`

## v0.0.7

* Avoid confusing `Typhoeus.stub` with RSpec's `stub` ([#4](https://github.com/yujinakayama/transpec/issues/4))

## v0.0.6

* Fix a bug where `SomeClass.any_instance.should_receive(:message).any_number_of_times` was converted into `expect_any_instance_of(SomeClass).to receive(:message)` unintentionally (now it's converted into `allow_any_instance_of(SomeClass).to receive(:message)`)

## v0.0.5

* Support conversion of `any_number_of_times`

## v0.0.4

* Fix a bug where necessary parentheses were not added when converting operator matcher to non-operator matcher in some cases (e.g. `== (2 - 1) + (1 + 2)` was converted into `eq(2 - 1) + (1 + 2)` unintentionally)

## v0.0.3

* Suppress addition of superfluous parentheses when converting operator matcher that have argument in parentheses to non-operator matcher (e.g. from `== (2 - 1)` to `eq(2 - 1)`)
* Support auto-modification of syntax configuration in `RSpec.configure`

## v0.0.2

* Support conversion from `be_close(expected, delta)` to `be_within(delta).of(expected)`

## v0.0.1

* Initial release
