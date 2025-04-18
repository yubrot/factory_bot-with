## [Unreleased]

## [0.6.0] - 2025-04-11

- Added: Factory methods are now also provided as class methods of `FactoryBot::With`
- Fixed: Removed some internal methods from `FactoryBot::With`

## [0.5.0] - 2025-03-20

- Added: When using `with` scope syntax, blocks can now take given objects as arguments
- Added: `with_list` also works as a scope syntax, but calls a block for each product of objects
- **Changed**: Passing blocks to factory methods behaves same as `with` scope syntax

## [0.4.0] - 2025-03-15

- Fixed: Improved error message for incorrect factory usage
- Added: Added `with` scope syntax for automatic association resolution

## [0.3.0] - 2024-12-09

- Added: Added `FactoryBot::With.register_strategy` to support custom strategies

## [0.2.1] - 2024-11-29

- Fixed: Adjusted priority of factory names autocompletion

## [0.2.0] - 2024-11-29

- Fixed: Fixed an incorrect factory resolution problem after factory names autocompletion
- Added: Smarter interpretation of positional arguments passed to factory methods

## [0.1.0] - 2024-11-27

- Initial release
