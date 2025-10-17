# Claude Agent Guide

This document provides guidance for AI agents working with the vision-server project.

## Testing Workflow

The project uses a unified Makefile-based workflow for building, running, and testing the server.

### Quick Test

To test the server with an image:

```bash
make test IMAGE=tests/meme.jpeg
```

This command will:
1. Stop any running server instance
2. Build the project
3. Start the server in the background (defaults to 127.0.0.1:8080)
4. Send the image to the `/analyze` endpoint
5. Display the JSON response
6. Stop the server

### Custom Host/Port Testing

You can specify custom HOST and PORT:

```bash
# Use a different port
make test IMAGE=tests/meme.jpeg PORT=3000

# Bind to all interfaces
make test IMAGE=tests/recipe.heic HOST=0.0.0.0 PORT=8080

# Both custom host and port
make test IMAGE=tests/meme.jpeg HOST=192.168.1.10 PORT=9000
```

### Server Management

**Start the server:**
```bash
make start
```

This builds the project, stops any existing instance, and starts the server in the background. The process ID is saved to `.server.pid` and the URL is saved to `.server.url`.

Default binding is `127.0.0.1:8080`. You can customize:

```bash
# Start on port 3000
make start PORT=3000

# Start on all interfaces
make start HOST=0.0.0.0

# Custom host and port
make start HOST=0.0.0.0 PORT=9000
```

**Stop the server:**
```bash
make stop
```

This kills the server process using the saved PID and removes the PID and URL files.

**Note:** Always use `make stop` to clean up the server. Do not use `pkill vision-server` directly.

### Building

```bash
make build
```

Builds the release binary at `.build/release/vision-server`.

### Cleaning

```bash
make clean
```

Removes all build artifacts, logs, and the PID file.

## Debugging

When tests fail or the server behaves unexpectedly, check the log files:

- **server.log** - Standard output (startup messages, request logs)
- **server.err.log** - Error output (crashes, exceptions, errors)

Example:
```bash
# View recent server output
tail -20 server.log

# View errors
cat server.err.log
```

## Process Management

The server uses two files to track state:

- **`.server.pid`** - Process ID of the running server
- **`.server.url`** - Full URL where the server is listening (e.g., `http://127.0.0.1:8080`)

This ensures:

- No leftover processes between test runs
- Clean shutdown when running multiple tests
- Agents can reliably start/stop the server
- Tests automatically use the correct URL

Both files are git-ignored and automatically managed by the Makefile.

## Common Agent Workflows

### Running a test with a specific image

```bash
make test IMAGE=path/to/image.jpg
```

### Testing with different configurations

```bash
# Test on default port
make test IMAGE=tests/meme.jpeg

# Test on custom port
make test IMAGE=tests/recipe.heic PORT=3000

# Test with custom host (e.g., testing network access)
make test IMAGE=tests/meme.jpeg HOST=0.0.0.0 PORT=8080
```

### Testing multiple images sequentially

```bash
make test IMAGE=tests/meme.jpeg
make test IMAGE=tests/recipe.heic
```

Each test run will automatically manage the server lifecycle.

### Manual testing (interactive mode)

```bash
# Start server
make start

# Run tests manually
curl -X POST -H "Content-Type: application/octet-stream" \
  --data-binary @tests/meme.jpeg \
  http://localhost:8080/analyze

# Stop when done
make stop
```

### Viewing logs during development

```bash
# Start server
make start

# In another terminal, tail logs
tail -f server.log

# Stop when done
make stop
```

## Important Notes

- Do NOT use complex shell scripts with `jq`, `&`, or manual PID tracking
- Do NOT use `pkill` directly - use `make stop`
- The test target outputs raw JSON without `jq` formatting
- All server management should go through the Makefile targets
- Logs are automatically captured and available for debugging
