# Changelog

## Development

* Fix a bug where `-p/--no-parentheses-matcher-arg` was not applied to the conversion of `have(n).items` with `expect`

## v1.3.1

* Proceed to conversion even if `rspec` didn't pass in dynamic analysis

## v1.3.0

* Handle singular collection names like `have(n).item` ([#18](https://github.com/yujinakayama/transpec/issues/18))
* Handle collection accessors with arguments like `have(n).errors_on(...)` ([#18](https://github.com/yujinakayama/transpec/issues/18))
* Handle `described_class.any_instance` ([#18](https://github.com/yujinakayama/transpec/issues/18))
* Handle indirect `any_instance` subject with runtime information  (e.g. `variable = SomeClass.any_instance; variable.stub(:message)`)
* Disable conversion of `have(n).items` automatically if `rspec-rails` or `rspec-collection_matchers` is loaded in the target project
* Disable conversion of `its` automatically if `rspec-its` is loaded in the target project

## v1.2.2

* Fix error `singleton can't be dumped (TypeError)` at the end of dynamic analysis ([#17](https://github.com/yujinakayama/transpec/issues/17))
* Do not copy pseudo files (device, socket, etc.) in dynamic analysis ([#17](https://github.com/yujinakayama/transpec/issues/17))
* Fix error `undefined method receive_messages_available?` while conversion ([#17](https://github.com/yujinakayama/transpec/issues/17))

## v1.2.1

* Apply `-p/--no-parentheses-matcher-arg` to the conversion of `have(n).items` (`obj.should have(n).items` is now converted to `expect(obj.size).to eq n` with `-p/--no-parentheses-matcher-arg`)

## v1.2.0

* Transpec is now ready for RSpec 2.99 and 3.0 beta!
* Support conversion to `allow(obj).to receive_messages(:message => value)` ([#6](https://github.com/yujinakayama/transpec/issues/6))
* Support conversion to `be_truthy` / `be_falsey` ([#8](https://github.com/yujinakayama/transpec/issues/8))
* Add `-b/--boolean-matcher` option that allows to specify matcher type that `be_true` and `be_false` will be converted to
* Abort if a target project's `rspec` gem dependency is older than the version required by Transpec

## v1.1.2

* Allow use of non monkey patch syntaxes in non example group contexts by including `RSpec::Matchers` ([#15](https://github.com/yujinakayama/transpec/issues/15))

## v1.1.1

* Fix failure of dynamic analysis when cwd was changed at exit of rspec

## v1.1.0

* Support conversion of `its` ([#9](https://github.com/yujinakayama/transpec/issues/9))

## v1.0.0

* Now Transpec does dynamic code analysis!
* Support conversion of `have(n).items` matcher ([#5](https://github.com/yujinakayama/transpec/issues/5))
* Add `-s/--skip-dynamic-analysis` option that allows to skip dynamic analysis and convert with only static analysis
* Add `-c/--rspec-command` option that allows to specify command to run RSpec that is used for dynamic analysis
* Check contexts correctly with runtime information
* Detect same name but non-RSpec methods with runtime information ([#4](https://github.com/yujinakayama/transpec/issues/4))
* Consider runtime type information when converting `=~` to `match_array`
* Rename `-d/--disable` option to `-k/--keep` and change its syntax types
* Rename `--commit-message` option to `--generate-commit-message`

## v0.2.6

* Fix a bug where `Node#each_descendent_node` enumerates only within depth 2

## v0.2.5

* Do not touch file if the source does need to be rewritten

## v0.2.4

* Improve context detection

## v0.2.3

* Fix a bug where arguments of positive error expectation with block were removed (e.g. `expect { }.to raise_error(SpecificErrorClass) { |e| ... }` was converted to `expect { }.to raise_error { |e| ... }` unintentionally)

## v0.2.2

* Fix a crash on syntax configuration with variable in `RSpec.configure` (e.g. `RSpec.configure { |config| config.expect_with { |c| c.syntax = some_syntax } }`)

## v0.2.1

* Fix a crash on operator matcher that have `__FILE__` in its arguments

## v0.2.0

* Display conversion summary at the end
* Add `-m/--commit-message` option that allows to generate commit message automatically

## v0.1.3

* Avoid confusing `Excon.stub` with RSpec's `stub` ([#4](https://github.com/yujinakayama/transpec/issues/4))
* Fix a bug where `be == 1` was converted into `be eq(1)` (now it's converted into `eq(1)`)
* Fix a bug where `obj.should==1` was converted into `obj.toeq1` (now it's converted into `obj.to eq(1)`)

## v0.1.2

* Continue processing files even if a file has invalid syntax
* Fix a crash on source `variable::Const`
* Fix generating invalid code with here document followed by method
* Fix generating invalid code when converting `obj.should() == 1`

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
