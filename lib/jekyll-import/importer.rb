# frozen_string_literal: true

module JekyllImport
  class Importer
    def self.inherited(base)
      subclasses << base
    end

    def self.subclasses
      @subclasses ||= []
    end

    def self.stringify_keys(hash)
      return hash unless hash.is_a?(Hash)

      the_hash = hash.clone
      hash.each_key do |key|
        begin
          the_hash[(key.to_s rescue key) || key] = the_hash.delete(key)
        rescue StandardError
          # Handle case where value of a key is not stringify-able
          next
        end
      end
      the_hash
    end

    def self.run(options = {})
      opts = stringify_keys(options)

      # Check if required dependencies are installed
      return unless required_deps_installed?

      validate(opts) if respond_to?(:validate)
      process(opts)
    end

    def self.required_deps_installed?
      # Implement check for required dependencies here
      true
    rescue StandardError
      # Handle case where required dependencies are not installed
      false
    end

    def self.validate(opts)
      # Implement validation logic here
    end

    def self.process(opts)
      # Implement processing logic here
    end
  end
end
