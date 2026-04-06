# Claude Local - LM Studio Model Selector

A script to connect to an LM Studio instance, query available models, and launch Claude Code with your selected model.

## Requirements

- Bash (macOS or Linux)
- `curl`
- `jq`
- LM Studio running locally (default: http://localhost:1234)
- Claude Code installed

## Installation

1. Clone or download this repository
2. Make the script executable:
   ```bash
   chmod +x claude-local.sh
   ```
3. Optionally, rename/install it somewhere in your `$PATH`
	(I have it as `~/bin/claude-local`)
	
## Usage

1. Start LM Studio and ensure it's running
2. Run the script:
   ```bash
   ./claude-local.sh
   ```

3. The script will:
   - Connect to your LM Studio instance
   - Display all available models in an interactive select menu
   - Let you select a model using arrow keys and Enter
   - Launch Claude Code with the selected model
   - Pass any additional command-line arguments to Claude Code

I've played around with having it add the `--bare` argument when launching claude, which (according to `claude --help`) does this:
```
Minimal mode: skip hooks, LSP, plugin sync, attribution, auto-memory, background prefetches, 
keychain reads, and CLAUDE.md auto-discovery. Sets CLAUDE_CODE_SIMPLE=1. Anthropic auth is 
strictly ANTHROPIC_API_KEY or apiKeyHelper via --settings (OAuth and keychain are never read). 
3P providers (Bedrock/Vertex/Foundry) use their own credentials. Skills still resolve via 
/skill-name. Explicitly provide context via: --system-prompt[-file], --append-system-prompt[-file], 
--add-dir (CLAUDE.md dirs), --mcp-config, --settings, --agents, --plugin-dir.
```
Doing this greatly reduces the amount of context consumed by the system prompts claude code injects 
(it's somewhere around 12k tokens as of claude code version 2.1.92), but it seems to cause confusion
about using the built-in tools, so it's currently commented out.


Also included but commented out is an option to just replace the system prompts entirely. I don't have a useful set of
replacement prompts yet, but it seems like this might be useful for specific models.

### Environment Variables

The script automatically sets these environment variables when launching Claude Code:
- `ANTHROPIC_BASE_URL`: Points to your LM Studio instance
- `ANTHROPIC_AUTH_TOKEN`: Set to "swordfish" (required for Claude Code to recognize the session)

## Configuration

The script connects to LM Studio at `http://localhost:1234` by default. You can configure this in two ways:

1. **Environment variable**: Set `LM_STUDIO_BASE_URL` in your environment
2. **Script variable**: Edit the default used when setting up the `ANTHROPIC_BASE_URL` variable in the script

Example:
```bash
export LM_STUDIO_BASE_URL="http://localhost:8080"
./claude-local.sh
```

## Troubleshooting

- **Command not found**: Ensure you have `curl` and `jq` installed.
- **Connection refused**: Make sure LM Studio is running and accessible
- **No models found**: Ensure LM Studio has models loaded
- **Claude Code not found**: Install Claude Code if not already installed

## Example Output

```
Using LM Studio at http://localhost:1234
============================================================

Available Models:
  llama-2-7b-chat.gguf2.Q4_K_M
  mistral-7b-instruct.gguf2.Q4_K_M
  phi-2.gguf2.Q4_K_M

Launching Claude Code with model: llama-2-7b-chat.gguf2.Q4_K_M

```
