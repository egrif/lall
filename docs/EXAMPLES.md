# Examples and Use Cases

## Basic Usage Examples

### Simple Key Search

Find API tokens across production environments:

```bash
lall -s api_token -g prod-us
```

Output:
```
| Key       | prod    | prod-s2 | prod-s3 |
|-----------|---------|---------|---------|
| api_token | tok_123 | tok_456 | tok_789 |
```

### Wildcard Pattern Matching

Find all database-related configuration:

```bash
lall -s database_* -e prod,staging
```

Output:
```
| Key          | prod                        | staging                     |
|--------------|-----------------------------|-----------------------------|
| database_url | postgres://prod.db:5432/app | postgres://staging.db:5432  |
| database_max | 100                         | 50                          |
```

### Environment with Custom Space and Region

Search for a key in an environment, overriding the default space and region:

```bash
lall -m "some_key" -e "prod-s5:custom-space:euc1"
```

This will search for `some_key` in the `prod-s5` environment, but will use `custom-space` for the space and `euc1` for the region when fetching data.


## Advanced Search Patterns

### Finding Configuration Drift

Compare timeout settings across all environments:

```bash
lall -s *timeout* -g prod-all -p -v
```

This shows:
- All timeout-related keys
- Values across all production environments  
- Full paths to identify configuration location
- Pivoted view for easy comparison

### Audit Secret Keys

List all secret keys without exposing values:

```bash
lall -s "*" -g prod-us | grep SECRET
```

Then expose specific secrets for debugging:

```bash
lall -s database_password -e prod-s2 -x
```

### Configuration Validation

Verify feature flags are consistent:

```bash
lall -s feature_* -g staging -v -p
```

Output shows which environments have different feature flag settings.

## Secret Management Examples

### Safe Secret Auditing

List secret keys without exposing values:

```bash
lall -s "*" -g prod-all | grep "SECRET"
```

### Expose Secrets for Debugging

**⚠️ Use with caution in production environments**

```bash
# Expose database credentials for troubleshooting
lall -s db_password -e staging-s2 -x

# Compare API keys across environments
lall -s api_secret -g staging -x -v
```

### Group Secret Management

Find shared secrets across environment groups:

```bash
# Find group secrets (shared across environments)
lall -s shared_* -g prod-us -x -p
```

## Output Format Examples

### Standard Table Format

```bash
lall -s redis_url -e prod,staging,dev
```

```
| Key       | prod              | staging           | dev               |
|-----------|-------------------|-------------------|-------------------|
| redis_url | redis://prod:6379 | redis://stage:6379| redis://local:6379|
```

### With Full Paths (`-p`)

```bash
lall -s redis_url -e prod,staging -p
```

```
| Path              | Key       | prod              | staging           |
|-------------------|-----------|-------------------|-------------------|
| configs.redis_url | redis_url | redis://prod:6379 | redis://stage:6379|
```

### Pivoted Format (`-v`)

```bash
lall -s redis_url -e prod,staging -v
```

```
| Env     | redis_url         |
|---------|-------------------|
| prod    | redis://prod:6379 |
| staging | redis://stage:6379|
```

### Combined Path + Pivot (`-p -v`)

```bash
lall -s "*url*" -e prod,staging -p -v -t30
```

```
| Env     | configs.database_url | configs.redis_url | services.api_url |
|---------|---------------------|-------------------|------------------|
| prod    | postgres://prod...  | redis://prod:6379 | https://api...   |
| staging | postgres://stag...  | redis://stag:6379 | https://stag...  |
```

## Troubleshooting Use Cases

### Debugging Environment Issues

1. **Find configuration differences causing issues:**

```bash
lall -s timeout -g prod-us -v
```

2. **Check if secrets are properly configured:**

```bash
lall -s "*_key" -e prod-s5 -x
```

3. **Verify service endpoints:**

```bash
lall -s "*_service*" -e prod,staging -p
```

### Configuration Drift Detection

Find environments with different configuration:

```bash
# Check all API-related config
lall -s api_* -g prod-all -v -p -t50

# Look for feature flag inconsistencies  
lall -s feature_* -g staging -v
```

### Security Auditing

1. **List all secret keys across environments:**

```bash
lall -s "*" -g prod-all | grep "SECRET" | sort | uniq
```

2. **Verify secret keys exist in all environments:**

```bash
lall -s encryption_key -g prod-all -v
```

3. **Check for hardcoded values (should be secrets):**

```bash
lall -s "*password*" -g prod-all -p | grep -v SECRET
```

## Performance Optimization Examples

### Large-Scale Queries

For queries across many environments, use these strategies:

```bash
# Use groups instead of listing all environments
lall -s config_key -g prod-all  # Good
lall -s config_key -e prod,prod-s2,prod-s3,prod-s4,prod-s5  # Avoid

# Use specific patterns instead of wildcards when possible
lall -s database_url -g prod-us  # Good
lall -s "*database*" -g prod-us  # Slower

# Limit output with truncation for initial exploration
lall -s "*" -g prod-us -t20  # Quick overview
```

### Debug Mode for Troubleshooting

Enable debug mode to see actual lotus commands:

```bash
lall -s api_token -e prod -d
```

This shows the exact `lotus` commands being executed, useful for:
- Verifying correct environments are queried
- Debugging lotus connectivity issues
- Understanding performance bottlenecks

## Integration Examples

### CI/CD Pipeline Integration

Check configuration consistency before deployment:

```bash
#!/bin/bash
# Verify critical config exists in target environment
MISSING=$(lall -s database_url,api_key,redis_url -e $DEPLOY_ENV | grep -c "^$")
if [ $MISSING -gt 0 ]; then
  echo "ERROR: Missing configuration in $DEPLOY_ENV"
  exit 1
fi
```

### Monitoring and Alerting

Regular configuration drift detection:

```bash
#!/bin/bash
# Check for configuration drift in production
RESULTS_FILE="/tmp/prod_config_$(date +%Y%m%d).txt"
lall -s "*" -g prod-us -v > $RESULTS_FILE

# Compare with previous day
if ! diff -q $RESULTS_FILE /tmp/prod_config_$(date -d yesterday +%Y%m%d).txt; then
  echo "Configuration drift detected in production!"
  # Send alert...
fi
```

### Development Workflow

Compare your local config with remote environments:

```bash
# Check if local config matches staging
lall -s database_* -e local,staging -v

# Verify feature flags before deployment
lall -s feature_* -e staging,prod -p -v
```

## Error Handling Examples

### Handling Missing Environments

```bash
# This will show empty columns for non-existent environments
lall -s api_token -e prod,nonexistent-env,staging
```

### Network Connectivity Issues

```bash
# Use debug mode to diagnose lotus connectivity
lall -s test -e prod -d

# The ping phase will fail if lotus can't connect
# Check lotus configuration: lotus ping -s prod
```

### Secret Access Issues

```bash
# If secret fetching fails, you'll see error messages
lall -s secret_key -e prod -x -d

# Check lotus secret permissions:
# lotus secret get secret_key -s prod -e prod -a greenhouse
```

## Best Practices

### Performance Best Practices

1. **Use environment groups** instead of long environment lists
2. **Be specific with search patterns** to reduce processing time  
3. **Use truncation** for initial exploration of large datasets
4. **Limit secret exposure** to only when necessary

### Security Best Practices

1. **Never expose secrets in logs or CI output**
2. **Use `-x` flag only in secure environments**  
3. **Audit secret usage regularly**
4. **Verify secret keys exist across all required environments**

### Operational Best Practices

1. **Use consistent naming patterns** for easier searching
2. **Document environment groups** in your team's runbook
3. **Regular configuration drift detection**
4. **Integrate with deployment pipelines** for validation
