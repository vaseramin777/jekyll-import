# frozen_string_literal: true

module JekyllImport
  module Importers
    Dir.chdir(File.join(File.dirname(__FILE__), 'importers')) do
      Dir.glob('**/*.rb').each do |file|
        require file
        constant = File.basename(file, '.rb').camelize.constantize
        Object.const_set("JekyllImport::Importers::#{constant.name}", constant)
      end
    end
  end
end
