# Mise Configuration

This directory contains mise (formerly rtx) configuration files, replacing the old asdf setup.

## Files

- `.config/mise/config.toml` - Main configuration file for tools and settings

## Usage

### Adding Tools
```bash
# Add a tool with a specific version
mise use node@20.0.0

# Add a tool with the latest version
mise use python@latest

# Add multiple tools at once
mise use node@20.0.0 python@3.11.0 ruby@3.2.0
```

### Managing Tools
```bash
# List installed tools
mise list

# Install all tools from config.toml
mise install

# Update all tools
mise update

# Remove a tool
mise uninstall node
```

### Project-specific Configuration
You can also create project-specific `mise.toml` or `.mise.toml` files in individual projects.

## Migration from asdf

If you have existing `.tool-versions` files, mise can read them automatically with the `legacy_version_file = true` setting.

## More Information

- [mise documentation](https://mise.jdx.dev/)
- [mise GitHub](https://github.com/jdx/mise)
