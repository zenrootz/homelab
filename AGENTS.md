# AGENTS.md - Homelab Multimodal Agent Project

## Build/Lint/Test Commands
- **Full automated deployment**: `./master_deploy.sh` (100% automated, no duplicates)
- **Clean and redeploy**: `./cleanup.sh && ./master_deploy.sh`
- **Build containers only**: `./build.sh`
- **Deploy services only**: `./deploy.sh`
- **Clean all resources**: `./cleanup.sh`
- **Build llama.cpp**: `cd llama.cpp && make clean && make -j$(nproc) LLAMA_ROCM=1`
- **Install deps**: `sudo dnf install libclblast libclblast-dev`
- **Run single test**: `./test_agent.sh` (or test_coder.sh, test_vision.sh, test_voice.sh)
- **Run all tests**: `./test_integration.sh`
- **Lint Python**: `cd llama.cpp && pre-commit run flake8 --all-files`
- **Lint web UI**: `cd llama.cpp/tools/server/webui && npm run lint`
- **Test web UI**: `cd llama.cpp/tools/server/webui && npm run test:unit`

## Code Style Guidelines

### Bash Scripts
- Use `#!/bin/bash` shebang with `set -e` for strict error handling
- Quote all variables: `"$variable"` and use `[[ ]]` for conditionals
- Functions: lowercase with underscores, descriptive names
- Error handling: `command || error_exit "message"` pattern
- Logging: `log "message"` function for consistent output
- Indentation: 2 spaces, executable permissions required

### Python (llama.cpp)
- Follow PEP8 with flake8 linting
- Type hints required for function parameters and returns
- Imports: standard library first, then third-party, then local
- Error handling: try/except with specific exceptions
- Naming: snake_case for functions/variables, PascalCase for classes

### TypeScript/JavaScript (Web UI)
- Use Prettier for formatting, ESLint for linting
- TypeScript preferred with strict type checking
- Component naming: PascalCase, hooks/functions: camelCase
- Error handling: try/catch with proper error types
- Imports: absolute paths, group by external/internal

### Configuration & Naming
- Variables: UPPERCASE_WITH_UNDERSCORES for env/shell
- Ports: sequential (8080-8084), document assignments
- Models: descriptive with quantization info (Q4_K_M, etc.)
- Files: lowercase with hyphens for scripts, descriptive names

### Error Handling & Security
- Validate inputs before processing
- Use absolute paths for file operations
- Log errors to stderr with timestamps
- Never commit vault/ directory (contains secrets)
- Check GPU/ROCm support before operations