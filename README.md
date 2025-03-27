<!-- markdownlint-disable MD036 -->
# RustEx

![RustEx Logo](./rustex.webp)

Rust application that monitors files for changes (text appending) and sends them to a Discord webhook.
Perfect for monitoring logs or other text files.

## Table of Contents

- [RustEx](#rustex)
  - [Table of Contents](#table-of-contents)
  - [Features](#features)
  - [Installation](#installation)
  - [Usage](#usage)
  - [Discord](#discord)

## Features

- Monitor multiple files
- Regex matching
- Discord webhook integration

## Installation

1. Fetch the latest release from the [Releases](https://github.com/stenstromen/rustex/releases/latest) page.
1. Extract the tarball.

## Usage

1. Create a config.yaml file.
1. Run the application.

```yaml
# config.yaml
---
webhook_url: https://discord.com/api/webhooks/.../...
files:
  - filename: /path/to/file1.log
    regex: ^\d{4}-\d{2}-\d{2}$
  - filename: /path/to/file2.log
    regex: ^\w+\s\w+$
  - filename: /path/to/file3.log
    regex: ERROR.*
```

```bash
./rustex config.yaml
```

## Discord

![Discord Webhook](./discord.webp)
