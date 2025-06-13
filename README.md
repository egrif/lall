# lall

A Ruby CLI tool for comparing YAML configuration values across multiple environments, using the `lotus` command to fetch environment data.

## Features
- Search for a string in YAML keys across one or more environments (supports exact and wildcard `*` matches)
- Output comparative tables (with or without path, pivoted or not)
- Truncation, case-insensitive search, and path display options
- Environment groups for quick multi-env queries (configurable in `config/settings.yml`)
- Threaded for fast parallel environment and secret fetches
- Secrets: Optionally expose secret values (with `-x/--expose`), fetching them in parallel and extracting only the value after `=`
- Debugging support with pry breakpoints
- Modular, maintainable code structure (SRP-compliant classes)

## Usage

```
lall -s STRING [-e ENV[,ENV2,...]] [-g GROUP] [-p] [-i] [-v] [-t[LEN]] [-x]
```

- `-s, --string=STRING`   : String to search for in YAML keys (required, supports wildcards)
- `-e, --env=ENV`         : Comma-separated environment(s) to search (mutually exclusive with -g)
- `-g, --group=GROUP`     : Predefined group of environments (mutually exclusive with -e)
- `-p, --path`            : Include the path column in the output table
- `-i, --insensitive`     : Case-insensitive key search
- `-v, --pivot`           : Pivot the table (environments as rows, keys/paths as columns)
- `-t, --truncate[=LEN]`  : Truncate output values longer than LEN (default 40)
- `-x, --expose`          : Expose secret values (fetches and displays actual secret values)

## Example

```
lall -s token* -g prod-all -p -v -t60 -x
```

## Folder Structure

```
lall/
  bin/
    lall                # Executable CLI entry point
  config/
    settings.yml        # Environment group definitions
  lib/
    lall/
      cli.rb            # LallCLI class (main logic and argument parsing)
      lotus_runner.rb   # LotusRunner class (lotus command execution, secret fetch, ping)
      key_searcher.rb   # KeySearcher class (YAML key search, secret fetch, parallelization)
      table_formatter.rb# TableFormatter class (table formatting/output)
      version.rb        # Gem version
  tmp/
    reference/
      prod.yaml
```

## Development
- Extend `TableFormatter` for more table types or output formats.
- Add new environment groups in `config/settings.yml`.
- Add tests and documentation as needed.
- All logic is modular and SRP-compliant for easy extension.

## Requirements
- Ruby 2.5+
- `lotus` command available in your PATH

## License
MIT
