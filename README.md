# Claude Local - local inference server model selector

A script to connect to a local inference server (oMLX, LM Studio, llama-server, etc.), query available models, and launch Claude Code with your selected model.

## Requirements

- Bash (macOS or Linux)
- `curl`
- `jq`
- A local inference server with an Anthropic-compatible endpoint (LM Studio/llama-server/oMLX/etc.)
- Claude Code installed

## Installation

1. Clone or download this repository
2. Make the script executable:
   ```bash
   chmod +x claude-local.sh
   ```
3. Optionally, rename/install it somewhere in your `$PATH`, or make a symlink that's in your `$PATH` that points to it
	(I have it symlinked as `~/bin/claude-local`)
	
## Usage

1. Start the inference server
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
- `ANTHROPIC_BASE_URL`: Base URL of the http/https endpoint it will connect to
- `ANTHROPIC_AUTH_TOKEN`: Bearer token for authentication to the endpoint
If you have `CLAUDE_LOCAL_BASE_URL` or `CLAUDE_LOCAL_AUTH_TOKEN` set in your environment, those will override 
the `ANTHROPIC` versions, as described in detail below.

## Configuration

The script connects to an endpoint at `http://localhost:1234` by default. You can configure this in two ways:

1. **Environment variable**: Set `CLAUDE_LOCAL_BASE_URL` or `ANTHROPIC_BASE_URL` in your environment
2. **Script variable**: Edit the default used when setting up the `ANTHROPIC_BASE_URL` variable in the script

Example:
```bash
export CLAUDE_LOCAL_BASE_URL="http://localhost:8080"
./claude-local.sh
```

The auth token can be set similarly by setting `CLAUDE_LOCAL_AUTH_TOKEN` or `ANTHROPIC_AUTH_TOKEN` in your environment.

Additionally, if you're on macOS you can add the auth token to your keychain, and the script will read it directly
as long as the keychain is unlocked (which it normally would be while you're logged in). It looks for an entry with a username
matching the base url, so if you use the script with different base urls you can have a keychain entry for each
and they shouldn't collide.

To add the key (be sure the url exactly matches your `ANTHROPIC_BASE_URL`, it's a plain string match):
```bash
security add-generic-password -s "claude-local" -a "http://localhost:1234" -w "auth-token-text"
```
and if you later want to delete it, use:
```bash
security delete-generic-password -s "claude-local" -a "http://localhost:1234"
```

If the `CLAUDE_LOCAL_MODEL` variable is set in the environment, the script will not query the model list or prompt to select a model,
and will just launch claude with the specified model ID.

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


Launching with model: qwen3.6-27b-ud-mlx

```

## Extra Features

The script will attempt to use specific model-listing endpoints provided by oMLX and LM Studio to provide richer information. 
(If those aren't available at the base URL it will fall back to the generic OpenAI-standard `/v1/models` endpoint.)

Under oMLX it will look something like this (models that are currently loaded are marked with ✅):

``` 
$ claude-local
using base url: http://localhost:1234
oMLX: 1/3 loaded, 0 loading, using 36.89GB of 107.52GB
Available Models:
      GLM-4.7-Flash-MLX-8bit (type:glm4_moe_lite window:198k, size:31.1G) 
      gpt-oss-20b-MXFP4-Q8 (type:gpt_oss window:128k, size:11.8G) 
   ✅ Qwen3.6-35B-A3B-MLX-8bit (type:qwen3_5_moe window:256k, size:36.9G) 
```

and LM Studio will look like this:

```
$ claude-local
using base url: http://127.0.0.1:12345

Available Models:
      Glm 4.7 Flash (key:zai-org/glm-4.7-flash, arch:glm4_moe_lite, format:mlx) 
      GPT-OSS 20B (key:openai/gpt-oss-20b, arch:gpt-oss, format:gguf) 
   ✅ Qwen3.6 35B A3B (key:qwen3.6-35b-a3b-mlx, arch:qwen3_5_moe, format:mlx) 
```

While connected to oMLX or LM Studio, it can also load and unload models directly from the menu (using the `l` and `u` or `x` keys, respectively).

With oMLX, unload will only work if you're authenticating with the main "administrative" API key -- sub-keys aren't authorized on the unload endpoint. 
