# Go Telescope Test

Use Telescope.nvim to find and select Go Tests to execute in a `jobterm()`.

Currently, only supports custom test runner.

##  Known Issues

It has ~5 seconds of latency for finding all tests in a large >1gb codebase.
This is a language server limitation. Grepping would be faster, however it
would also find non-tests in some cases.

### Features

- [ ] Support async jobs 
- [ ] Test Runner Configuration 
- [ ] RipGrep Support 
- [ ] CTags Support
