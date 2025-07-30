# frozen_string_literal: true

# lib/lall/cli_options.rb
module Cli
  class Options
    DEFAULTS = {
      path_also: false,
      insensitive: false,
      pivot: false,
      truncate: 40,
      expose: false,
      debug: false
    }.freeze

    attr_reader :options

    def initialize(opts = {})
      @options = DEFAULTS.merge(opts.transform_keys(&:to_sym))
      # Special handling for truncate: if explicitly set to nil, use default
      @options[:truncate] = DEFAULTS[:truncate] if opts.key?(:truncate) && opts[:truncate].nil?
    end

    def method_missing(name, *args, &block)
      if @options.key?(name)
        @options[name]
      else
        super
      end
    end

    def respond_to_missing?(name, include_private = false)
      @options.key?(name) || super
    end
  end
end
