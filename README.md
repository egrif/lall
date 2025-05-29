# lall

A Ruby CLI tool for comparing YAML configuration values across multiple environments, using the `lotus` command to fetch environment data.

## Features
- Search for a string in YAML keys across one or more environments
- Output comparative tables (with or without path, pivoted or not)
- Truncation, case-insensitive search, and path display options
- Environment groups for quick multi-env queries
- Threaded for fast parallel environment fetches
- Debugging support with pry breakpoints

## Usage

```
lall -s STRING [-e ENV[,ENV2,...]] [-g GROUP] [-p] [-i] [-v] [-t[LEN]]
```

- `-s, --string=STRING`   : String to search for in YAML keys (required)
- `-e, --env=ENV`         : Comma-separated environment(s) to search (mutually exclusive with -g)
- `-g, --group=GROUP`     : Predefined group of environments (mutually exclusive with -e)
- `-p, --path`            : Include the path column in the output table
- `-i, --insensitive`     : Case-insensitive key search
- `-v, --pivot`           : Pivot the table (environments as rows, keys/paths as columns)
- `-t, --truncate[=LEN]`  : Truncate output values longer than LEN (default 40)

## Example

```
lall -s token -g prod-all -p -v -t60
```

## Folder Structure

```
lall/
  bin/
    lall                # Executable CLI entry point
  lib/
    lall/
      cli.rb            # LallCLI class (main logic and argument parsing)
      lotus_runner.rb   # LotusRunner class (lotus command execution)
      key_searcher.rb   # KeySearcher class (YAML key search)
      table_formatter.rb# TableFormatter class (table formatting/output)
  tmp/
    reference/
      prod.yaml
```

## Development
- Extend `TableFormatter` for more table types or output formats.
- Add new environment groups in `ENV_GROUPS` in `cli.rb`.
- Add tests and documentation as needed.

## Requirements
- Ruby 2.5+
- `lotus` command available in your PATH

## License
MIT
