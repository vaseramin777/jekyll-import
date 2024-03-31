# frozen_string_literal: true

module JekyllImport
  # Constants should be in UPPER_SNAKE_CASE
  VERSION = "0.24.0"

  # Add a comment describing what this module does
  module_function

  # Version number should be a method, not a constant
  def version
    VERSION
  end
end

