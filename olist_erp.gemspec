# frozen_string_literal: true

require_relative "lib/olist_erp/version"

Gem::Specification.new do |spec|
  spec.name = "olist_erp"
  spec.version = OlistErp::VERSION
  spec.authors = ["Diego Bentes"]
  spec.email = ["diegopbentes@gmail.com"]

  spec.summary = "Cliente Ruby para a API v3 do ERP da Olist (ex-Tiny)"
  spec.description = "Cliente Ruby da API v3 do ERP da Olist (ex-Tiny ERP): OAuth 2, produtos, " \
                     "estoque, preços, categorias, marcas, depósitos e listas de preço, com " \
                     "tratamento de limite de requisições e paginação automática."
  spec.homepage = "https://github.com/diegobentes/olist_erp"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir[
    "lib/**/*.rb",
    "sig/**/*.rbs",
    "README.md",
    "CHANGELOG.md",
    "LICENSE.txt"
  ]
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", ">= 2.0", "< 3.0"
end
