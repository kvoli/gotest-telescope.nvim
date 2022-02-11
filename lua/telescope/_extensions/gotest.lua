local gotest_builtin = require'telescope._extensions.gotest_builtin'

return require'telescope'.register_extension{
  exports = {
    gotest = gotest_builtin.gotest,
  },
}
