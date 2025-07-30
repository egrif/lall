# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cli::Options do
  describe '#initialize' do
    it 'sets default values when no options provided' do
      options = Cli::Options.new
      
      expect(options.path_also).to be false
      expect(options.insensitive).to be false
      expect(options.pivot).to be false
      expect(options.truncate).to eq 40
      expect(options.expose).to be false
      expect(options.debug).to be false
    end

    it 'merges provided options with defaults' do
      options = Cli::Options.new(
        path_also: true,
        insensitive: true,
        truncate: 100
      )
      
      expect(options.path_also).to be true
      expect(options.insensitive).to be true
      expect(options.pivot).to be false
      expect(options.truncate).to eq 100
      expect(options.expose).to be false
      expect(options.debug).to be false
    end

    it 'handles string keys by converting to symbols' do
      options = Cli::Options.new(
        'path_also' => true,
        'truncate' => 50
      )
      
      expect(options.path_also).to be true
      expect(options.truncate).to eq 50
    end

    it 'uses default truncate value when explicitly set to nil' do
      options = Cli::Options.new(truncate: nil)
      
      expect(options.truncate).to eq 40
    end
  end

  describe 'method_missing' do
    it 'returns option values for known options' do
      options = Cli::Options.new(custom_option: 'test_value')
      
      expect(options.custom_option).to eq 'test_value'
    end

    it 'raises error for unknown options' do
      options = Cli::Options.new
      
      expect { options.unknown_option }.to raise_error(NoMethodError)
    end
  end

  describe 'respond_to_missing?' do
    it 'returns true for known options' do
      options = Cli::Options.new(test_option: true)
      
      expect(options.respond_to?(:test_option)).to be true
    end

    it 'returns false for unknown options' do
      options = Cli::Options.new
      
      expect(options.respond_to?(:unknown_option)).to be false
    end
  end
end
