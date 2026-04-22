# Claude Local - LM Studio/llama-server Model Selector

A script to connect to an LM Studio or llama-server endpoint, query available models, and launch Claude Code with your selected model.

## Requirements

- Bash (macOS or Linux)
- `curl`
- `jq`
- LM Studio/llama-server running locally (default: http://localhost:1234)
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

1. Start LM Studio or llama-server and ensure it's running
2. Run the script:
   ```bash
   ./claude-local.sh
   ```

3. The script will:
   - Connect to the specified endpoint
   - Display all available models in an interactive select menu
   - Let you select a model using arrow keys and Enter
   - Launch Claude Code with the selected model
   - Pass any additional command-line arguments to Claude Code

The script replaces the default claude code system prompt, and also limits which tools it has available.

I started with the configuration laid out in this post:

https://spicyneuron.substack.com/p/a-mac-studio-for-local-ai-6-months

and have been tuning it to my own preferences. See the script content for details.

### Environment Variables

The script automatically sets these environment variables when launching Claude Code:
- `ANTHROPIC_BASE_URL`: Points to your LM Studio instance
- `ANTHROPIC_AUTH_TOKEN`: Set to "swordfish" (required for Claude Code to recognize the session)

## Configuration

The script connects to an endpoint at `http://localhost:1234` by default. You can configure this in two ways:

1. **Environment variable**: Set `LM_STUDIO_BASE_URL` in your environment
2. **Script variable**: Edit the default used when setting up the `ANTHROPIC_BASE_URL` variable in the script

Example:
```bash
export LM_STUDIO_BASE_URL="http://localhost:8080"
./claude-local.sh
```

## Troubleshooting

- **Command not found**: Ensure you have `curl` and `jq` installed.
- **Connection refused**: Make sure the process providing the endpoint is running and accessible
- **No models found**: Ensure there is at least one model available
- **Claude Code not found**: Install Claude Code if not already installed

## Example Output

```
$ ./claude-local.sh 
Using endpoint at http://localhost:1234
============================================================

Available Models:
   Qwen3.6 27B UD (key:qwen3.6-27b-ud-mlx, arch:qwen3_5, format:mlx) 
   Qwen3.6 35B A3B (key:qwen/qwen3.6-35b-a3b, arch:qwen35moe, format:gguf) 
   Gemma 4 26B A4B 4 Vision (key:gemma-4-26b-a4b-mlx-4-vision, arch:gemma4, format:mlx) 
   Glm 4.7 Flash (key:zai-org/glm-4.7-flash, arch:glm4_moe_lite, format:mlx) 


Launching Claude Code with model: qwen3.6-27b-ud-mlx

```
