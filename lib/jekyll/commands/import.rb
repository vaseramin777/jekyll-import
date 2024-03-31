# frozen_string_literal: true

module Jekyll
  module Commands
    class Import < Command
      # Mapping of migrator names to their corresponding classes
      IMPORTERS = {
        blogger:         "Blogger",
        behance:         "Behance",
        csv:             "CSV",
        drupal6:         "Drupal6",
        drupal7:         "Drupal7",
        enki:            "Enki",
        joomla:          "Joomla",
        joomla3:         "Joomla3",
        jrnl:            "Jrnl",
        ghost:           "Ghost",
        google_reader:   "GoogleReader",
        marley:          "Marley",
        mephisto:        "Mephisto",
        mt:              "MT",
        posterous:       "Posterous",
        rss:             "RSS",
        s9y:             "S9Y",
        textpattern:     "TextPattern",
        tumblr:          "Tumblr",
        typo:            "Typo",
        wordpress:       "WordPress",
        wordpressdotcom: "WordpressDotCom",
      }.freeze

      class << self
        def init_with_program(prog)
          prog.command(:import) do |c|
            c.syntax "import <platform> [options]"
            c.description "Import your old blog to Jekyll"
            importers = JekyllImport.add_importer_commands(c)

            c.action do |args, _options|
              if args.empty?
                puts "You must specify an importer."
                puts "Valid options are:"
                IMPORTERS.each_key { |i| puts "* #{i}" }
              end
            end
          end
        end

        def process(migrator, options)
          migrator = migrator.to_s.downcase

          if IMPORTERS.key?(migrator.to_sym)
            begin
              klass = const_get(IMPORTERS[migrator.to_sym])
              if options.respond_to?(:__hash__)
                klass.run(options.__hash__)
              else
                klass.run(options)
              end
            rescue NameError
              abort_on_invalid_migrator(migrator)
            end
          else
            abort_on_invalid_migrator(migrator)
          end
        end

        def abort_on_invalid_migrator(migrator)
          puts "Sorry, '#{migrator}' isn't a valid migrator. Valid choices:"
          IMPORTERS.each_key { |k| puts "* #{k}" }
          abort "'#{migrator}' is not a valid migrator."
        end
      end
    end
  end
end
