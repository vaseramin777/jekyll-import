# frozen_string_literal: true

# Override `site.url` with the Netlify Deploy Preview URL for seamless navigation during review.
# Delete this plugin once the templates start rendering relative URLs to the subpages.

return unless ENV.key?("NETLIFY")
return if ENV.fetch("DEPLOY_PRIME_URL", "").empty?

require "jekyll"

Jekyll::Hooks.register(:site, :after_init) do |site|
  site.config["url"] = ENV["DEPLOY_PRIME_URL"]
end
