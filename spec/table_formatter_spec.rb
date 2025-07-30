# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TableFormatter do
  let(:envs) { ['env1', 'env2'] }
  let(:env_results) do
    {
      'env1' => [
        { path: 'configs.api_token', key: 'api_token', value: 'token123' },
        { path: 'configs.timeout', key: 'timeout', value: '30' }
      ],
      'env2' => [
        { path: 'configs.api_token', key: 'api_token', value: 'token456' },
        { path: 'configs.timeout', key: 'timeout', value: '45' }
      ]
    }
  end
  let(:options) { { truncate: 40, path_also: false } }

  describe '.truncate_middle' do
    it 'returns original string when shorter than max length' do
      result = TableFormatter.truncate_middle('short', 10)
      expect(result).to eq('short')
    end

    it 'returns original string when max_len is less than 5' do
      result = TableFormatter.truncate_middle('very long string', 4)
      expect(result).to eq('very long string')
    end

    it 'truncates in the middle with ellipsis' do
      result = TableFormatter.truncate_middle('this is a very long string', 15)
      expect(result).to eq('this i...string')
    end

    it 'handles even length truncation' do
      result = TableFormatter.truncate_middle('abcdefghij', 8)
      expect(result).to eq('ab...ij')
    end

    it 'handles odd length truncation' do
      result = TableFormatter.truncate_middle('abcdefghijk', 9)
      expect(result).to eq('abc...ijk')
    end
  end

  describe '#initialize' do
    it 'sets instance variables correctly' do
      columns = ['api_token', 'timeout']
      formatter = TableFormatter.new(columns, envs, env_results, options)
      
      expect(formatter.instance_variable_get(:@columns)).to eq(columns)
      expect(formatter.instance_variable_get(:@envs)).to eq(envs)
      expect(formatter.instance_variable_get(:@env_results)).to eq(env_results)
      expect(formatter.instance_variable_get(:@options)).to eq(options)
    end

    it 'calculates environment width correctly' do
      formatter = TableFormatter.new([], ['short', 'very_long_env'], env_results, options)
      env_width = formatter.instance_variable_get(:@env_width)
      
      expect(env_width).to eq('very_long_env'.length)
    end
  end

  describe '#compute_col_widths' do
    context 'without path_also option' do
      let(:columns) { ['api_token', 'timeout'] }
      let(:formatter) { TableFormatter.new(columns, envs, env_results, options) }

      it 'computes column widths based on header and data' do
        widths = formatter.compute_col_widths
        
        expect(widths.length).to eq(2)
        expect(widths[0]).to be >= 'api_token'.length
        expect(widths[1]).to be >= 'timeout'.length
      end

      it 'considers truncation in width calculation' do
        truncated_options = options.merge(truncate: 5)
        formatter = TableFormatter.new(columns, envs, env_results, truncated_options)
        widths = formatter.compute_col_widths
        
        # Width should be at least the header length even with truncation
        expect(widths[0]).to be >= 'api_token'.length
      end
    end

    context 'with path_also option' do
      let(:columns) do
        [
          { path: 'configs.api_token', key: 'api_token' },
          { path: 'configs.timeout', key: 'timeout' }
        ]
      end
      let(:path_options) { options.merge(path_also: true) }
      let(:formatter) { TableFormatter.new(columns, envs, env_results, path_options) }

      it 'computes widths using path.key format' do
        widths = formatter.compute_col_widths
        
        expect(widths.length).to eq(2)
        expect(widths[0]).to be >= 'configs.api_token.api_token'.length
      end
    end
  end

  describe '#build_header' do
    context 'without path_also option' do
      let(:columns) { ['api_token', 'timeout'] }
      let(:formatter) { TableFormatter.new(columns, envs, env_results, options) }

      it 'builds header with environment and key columns' do
        col_widths = [10, 8]
        header = formatter.build_header(col_widths)
        
        expect(header).to include('Env')
        expect(header).to include('api_token')
        expect(header).to include('timeout')
        expect(header).to include('|')
      end
    end

    context 'with path_also option' do
      let(:columns) do
        [
          { path: 'configs.api_token', key: 'api_token' },
          { path: 'configs.timeout', key: 'timeout' }
        ]
      end
      let(:path_options) { options.merge(path_also: true) }
      let(:formatter) { TableFormatter.new(columns, envs, env_results, path_options) }

      it 'builds header with path.key format' do
        col_widths = [20, 15]
        header = formatter.build_header(col_widths)
        
        expect(header).to include('configs.api_token.api_token')
        expect(header).to include('configs.timeout.timeout')
      end
    end
  end

  describe '#print_table' do
    let(:columns) { ['api_token', 'timeout'] }
    let(:formatter) { TableFormatter.new(columns, envs, env_results, options) }

    it 'prints formatted table to stdout' do
      expect { formatter.print_table }.to output(/api_token.*timeout/).to_stdout
      expect { formatter.print_table }.to output(/env1.*token123.*30/).to_stdout
      expect { formatter.print_table }.to output(/env2.*token456.*45/).to_stdout
    end

    it 'includes separator lines' do
      expect { formatter.print_table }.to output(/\|-+/).to_stdout
    end

    context 'with truncation' do
      let(:long_env_results) do
        {
          'env1' => [
            { path: 'configs.api_token', key: 'api_token', value: 'very_long_token_value_that_should_be_truncated' }
          ]
        }
      end
      let(:truncated_options) { options.merge(truncate: 10) }
      let(:formatter) { TableFormatter.new(['api_token'], ['env1'], long_env_results, truncated_options) }

      it 'truncates long values' do
        expect { formatter.print_table }.to output(/\.\.\./).to_stdout
      end
    end
  end

  describe '#print_key_table' do
    let(:formatter) { TableFormatter.new([], envs, env_results, options) }
    let(:all_keys) { ['api_token', 'timeout'] }

    it 'prints key-based table' do
      expect { formatter.print_key_table(all_keys, envs, env_results) }.to output(/Key.*env1.*env2/).to_stdout
      expect { formatter.print_key_table(all_keys, envs, env_results) }.to output(/api_token.*token123.*token456/).to_stdout
    end

    it 'only prints rows with values' do
      empty_env_results = {
        'env1' => [],
        'env2' => []
      }
      
      output = capture_stdout { formatter.print_key_table(all_keys, envs, empty_env_results) }
      # Should only contain header and separator, no data rows
      lines = output.split("\n")
      expect(lines.length).to eq(2) # header + separator only
    end
  end

  describe '#print_path_table' do
    let(:formatter) { TableFormatter.new([], envs, env_results, options) }
    let(:all_paths) { ['configs.api_token', 'configs.timeout'] }
    let(:all_keys) { ['api_token', 'timeout'] }

    it 'prints path and key based table' do
      expect { formatter.print_path_table(all_paths, all_keys, envs, env_results) }.to output(/Path.*Key.*env1.*env2/).to_stdout
    end

    it 'includes path and key columns' do
      output = capture_stdout { formatter.print_path_table(all_paths, all_keys, envs, env_results) }
      expect(output).to include('configs.api_token')
      expect(output).to include('api_token')
    end
  end

  private

  def capture_stdout
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end
end
