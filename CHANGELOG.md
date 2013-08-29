# Changelog

## Master

* Suppress addition of superfluous parentheses when converting operator matcher that have argument in parentheses to non-operator matcher (e.g. from `== (2 - 1)` to `eq(2 - 1)`)

## v0.0.2

* Support conversion from `be_close(expected, delta)` to `be_within(delta).of(expected)`

## v0.0.1

* Initial release
