# Changelog

## Master

* Fix a bug where necessary parentheses were not added when converting operator matcher to non-operator matcher in some cases (e.g. `== (2 - 1) + (1 + 2)` was converted into `eq(2 - 1) + (1 + 2)` unintentionally)

## v0.0.3

* Suppress addition of superfluous parentheses when converting operator matcher that have argument in parentheses to non-operator matcher (e.g. from `== (2 - 1)` to `eq(2 - 1)`)
* Support auto-modification of syntax configuration in `RSpec.configure`

## v0.0.2

* Support conversion from `be_close(expected, delta)` to `be_within(delta).of(expected)`

## v0.0.1

* Initial release
