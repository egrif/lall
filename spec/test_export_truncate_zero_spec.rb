require 'spec_helper'

RSpec.describe 'Export truncation with zero value' do
  let(:long_value_env_results) do
    {
      'env1' => [{ key: 'long_key', value: 'this_is_a_very_long_value_that_should_not_be_truncated',
                   path: 'configs', color: :white }]
    }
  end

  let(:long_value_entity_set) do
    double('entity_set',
           environments: [
             double('env1', name: 'env1',
                            data: { 'configs' => { 'long_key' => 'this_is_a_very_long_value_that_should_not_be_truncated' } })
           ],
           groups: [])
  end

  before do
    allow(long_value_entity_set).to receive(:fetch_all)
    allow(long_value_entity_set).to receive(:environments).and_return(long_value_entity_set.environments)
    allow_any_instance_of(LallCLI).to receive(:create_entity_set).and_return(long_value_entity_set)
    allow_any_instance_of(LallCLI).to receive(:fetch_results_from_entity_set).and_return(long_value_env_results)
  end

  it 'does not truncate JSON exports when --no-truncate (-T) is specified' do
    cli = LallCLI.new(['-m', 'long_key', '-e', 'env1', '--format=json', '-T'])
    
    output = capture(:stdout) { cli.run }
    
    # Should not have ellipsis
    expect(output).not_to include('...')
    # Should have full value
    expect(output).to include('this_is_a_very_long_value_that_should_not_be_truncated')
  end

  it 'does not truncate YAML exports when --truncate=0 is specified' do
    cli = LallCLI.new(['-m', 'long_key', '-e', 'env1', '--format=yaml', '--truncate=0'])
    
    output = capture(:stdout) { cli.run }
    
    expect(output).not_to include('...')
    expect(output).to include('this_is_a_very_long_value_that_should_not_be_truncated')
  end

  it 'does not truncate TXT exports when -T is specified' do
    cli = LallCLI.new(['-m', 'long_key', '-e', 'env1', '--format=txt', '-T'])
    
    output = capture(:stdout) { cli.run }
    
    expect(output).not_to include('...')
    expect(output).to include('this_is_a_very_long_value_that_should_not_be_truncated')
  end
end
