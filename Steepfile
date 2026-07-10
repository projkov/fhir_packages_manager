# frozen_string_literal: true

D = Steep::Diagnostic

target :lib do
  signature 'sig'

  check 'lib'

  library 'json'
  library 'yaml'
  library 'net-http'
  library 'uri'
  library 'optparse'
  library 'fileutils'

  configure_code_diagnostics(D::Ruby.default)
end
