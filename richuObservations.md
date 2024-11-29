# Observations and questions by a dumb guy

## Observations

- Code feels extremely bloated.
- Depending on Solidity compilers as old as `0.4.18`: not recommended if it can be avoided. Only go for compilers above `0.8.0` because of advanced features and breaking changes. And that too newer versions, not `0.8.17`.
- Solidity optimizer in hardhat.config file is set to 10, which is very low. As a long term project, I think it's better to prioritize gas optimizations as opposed to code size.

## Questions

- Tests are passing and failing un-deterministically, without doing any code edits. What's happening?
