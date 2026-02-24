# base-macOS

Base policy for macOS, granting basic permissions for common system directories, built-in processes, and localhost.

## What's Included

### File Access

* System directories (mostly read-only)
* User config directories
* Homebrew paths

### Process Execution

* System binaries
* Ash test and ping

### Network Access

* Localhost only: `127.0.0.1`, `::1`, `localhost`

### Environment Variables

* Built-in ENV variables
* Homebrew ENV variables
