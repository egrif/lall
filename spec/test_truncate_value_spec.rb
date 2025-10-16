require 'spec_helper'

RSpec.describe 'Test raw options truncate value' do
  before do
    allow(Lotus::Runner).to receive(:ping).and_return(true)
  end

  it 'checks the value of raw_options truncate when not set' do
    cli = LallCLI.new(['-m', 'test', '-e', 'env1'])
    raw_options = cli.instance_variable_get(:@raw_options)
    puts "\n\nRaw options truncate when not set: #{raw_options[:truncate].inspect}"
    puts "Truthy? #{!!raw_options[:truncate]}"
    puts "Positive? #{raw_options[:truncate]&.positive?}"
    expect(raw_options[:truncate]).to be_nil
  end

  it 'checks the value of raw_options truncate when set to 0 with -T' do
    cli = LallCLI.new(['-m', 'test', '-e', 'env1', '-T'])
    raw_options = cli.instance_variable_get(:@raw_options)
    puts "\n\nRaw options truncate with -T: #{raw_options[:truncate].inspect}"
    puts "Truthy? #{!!raw_options[:truncate]}"
    puts "Positive? #{raw_options[:truncate]&.positive?}"
    expect(raw_options[:truncate]).to eq(0)
  end

  it 'checks the value of raw_options truncate when set to 20' do
    cli = LallCLI.new(['-m', 'test', '-e', 'env1', '-t20'])
    raw_options = cli.instance_variable_get(:@raw_options)
    puts "\n\nRaw options truncate with -t20: #{raw_options[:truncate].inspect}"
    puts "Truthy? #{!!raw_options[:truncate]}"
    puts "Positive? #{raw_options[:truncate]&.positive?}"
    expect(raw_options[:truncate]).to eq(20)
  end
end
