[![MseeP.ai Security Assessment Badge](https://mseep.net/pr/ulucaydin-mcp-server-newrelic-badge.png)](https://mseep.ai/app/ulucaydin-mcp-server-newrelic)

# New Relic NerdGraph MCP Server

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) server for the [New Relic NerdGraph API](https://docs.newrelic.com/docs/apis/nerdgraph/get-started/introduction-new-relic-nerdgraph/), built with [fastmcp](https://github.com/jlowin/fastmcp). It lets MCP clients like Claude Desktop query and manage your New Relic data.

## Quickstart

You need a New Relic [User API key](https://docs.newrelic.com/docs/apis/intro-apis/new-relic-api-keys/#user-api-key) (`NRAK-...`) and your account ID. Pick one of the two setups below.

### Option A — Local (Python 3.10+)

```bash
git clone https://github.com/arelstone/mcp-server-newrelic.git
cd mcp-server-newrelic

python3 -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate

pip install -r requirements.txt

export NEW_RELIC_API_KEY="YOUR_API_KEY"
export NEW_RELIC_ACCOUNT_ID="YOUR_ACCOUNT_ID"

fastmcp run server.py:mcp          # stdio transport (what Claude Desktop expects)
```

For network clients, serve over HTTP instead:

```bash
fastmcp run server.py:mcp --transport http --host 127.0.0.1 --port 8000
```

### Option B — Docker

```bash
docker build -t mcp-server-newrelic .

docker run --rm -p 8000:8000 \
  -e NEW_RELIC_API_KEY="YOUR_API_KEY" \
  -e NEW_RELIC_ACCOUNT_ID="YOUR_ACCOUNT_ID" \
  mcp-server-newrelic
```

The image defaults to HTTP on port `8000`; the MCP endpoint is `http://127.0.0.1:8000/mcp/`.

## Configuration

The server is configured via environment variables:

| Variable                 | Required | Default                            | Description                                                                 |
| ------------------------ | -------- | ---------------------------------- | --------------------------------------------------------------------------- |
| `NEW_RELIC_API_KEY`      | **Yes**  | —                                  | New Relic User API key (`NRAK-...`). The server won't start without it.      |
| `NEW_RELIC_ACCOUNT_ID`   | No\*     | —                                  | Default account ID used when a tool call omits `target_account_id`.         |
| `NERDGRAPH_URL`          | No       | `https://api.newrelic.com/graphql` | Override the endpoint, e.g. `https://api.eu.newrelic.com/graphql` for EU accounts. |

\* Not required to start, but most tools fail without an account ID unless you pass `target_account_id` per call.

## Connecting Claude Desktop

Claude Desktop launches the server itself over stdio. Add an entry to its config file
(`~/Library/Application Support/Claude/claude_desktop_config.json` on macOS,
`%APPDATA%\Claude\claude_desktop_config.json` on Windows), then restart Claude Desktop.

**Local install** (use absolute paths):

```json
{
  "mcpServers": {
    "newrelic": {
      "command": "/abs/path/to/mcp-server-newrelic/.venv/bin/fastmcp",
      "args": ["run", "/abs/path/to/mcp-server-newrelic/server.py:mcp"],
      "env": {
        "NEW_RELIC_API_KEY": "YOUR_API_KEY",
        "NEW_RELIC_ACCOUNT_ID": "YOUR_ACCOUNT_ID"
      }
    }
  }
}
```

**Docker** (stdio transport, container per session):

```json
{
  "mcpServers": {
    "newrelic": {
      "command": "docker",
      "args": ["run", "-i", "--rm",
               "-e", "NEW_RELIC_API_KEY", "-e", "NEW_RELIC_ACCOUNT_ID",
               "mcp-server-newrelic", "--transport", "stdio"],
      "env": {
        "NEW_RELIC_API_KEY": "YOUR_API_KEY",
        "NEW_RELIC_ACCOUNT_ID": "YOUR_ACCOUNT_ID"
      }
    }
  }
}
```

## Connecting Claude Code

If you use the Claude Code CLI, register the server with `claude mcp add` instead of editing JSON.

**Local install** (stdio, absolute paths):

```bash
claude mcp add newrelic \
  -e NEW_RELIC_API_KEY=YOUR_API_KEY \
  -e NEW_RELIC_ACCOUNT_ID=YOUR_ACCOUNT_ID \
  -- /abs/path/to/mcp-server-newrelic/.venv/bin/fastmcp run /abs/path/to/mcp-server-newrelic/server.py:mcp
```

**Docker** (stdio):

```bash
claude mcp add newrelic \
  -e NEW_RELIC_API_KEY=YOUR_API_KEY \
  -e NEW_RELIC_ACCOUNT_ID=YOUR_ACCOUNT_ID \
  -- docker run -i --rm -e NEW_RELIC_API_KEY -e NEW_RELIC_ACCOUNT_ID mcp-server-newrelic --transport stdio
```

**HTTP** (point at an already-running server):

```bash
claude mcp add --transport http newrelic http://127.0.0.1:8000/mcp/
```

Add `-s user` or `-s project` to change scope (default `local`; `project` writes a shareable `.mcp.json`). Manage with `claude mcp list`, `claude mcp get newrelic`, and `claude mcp remove newrelic`.

## Using the Tools

Once connected, ask in natural language ("Show me my APM applications", "List open critical incidents in account 1234567") or invoke tools directly (`list_apm_applications()`).

## Available Tools & Resources

Optional `target_account_id` arguments fall back to `NEW_RELIC_ACCOUNT_ID` when omitted. All tools return a JSON string.

### Common (`features/common.py`)

| Name | Type | Description |
| ---- | ---- | ----------- |
| `query_nerdgraph` | Tool | Run an arbitrary NerdGraph query. Args: `nerdgraph_query` (str), `variables` (optional dict). |
| `run_nrql_query` | Tool | Run a NRQL query. Args: `nrql` (str), `target_account_id` (optional). |
| `get_account_details` | Resource | Account ID and name. URI: `newrelic://account_details`. |

### Entities (`features/entities.py`)

| Name | Type | Description |
| ---- | ---- | ----------- |
| `search_entities` | Tool | Search entities. Args: `name`, `entity_type`, `domain`, `tags`, `target_account_id`, `limit` (default 50) — all optional. |
| `get_entity_details` | Resource | Details for an entity by GUID. URI: `newrelic://entity/{guid}`. |
| `generate_entity_search_query` | Prompt | Builds an `entitySearch` query condition. Args: `entity_name` (str), `entity_domain`, `entity_type`, `target_account_id`. |

### APM (`features/apm.py`)

| Name | Type | Description |
| ---- | ---- | ----------- |
| `list_apm_applications` | Tool | List APM applications. Args: `target_account_id` (optional). |

### Synthetics (`features/synthetics.py`)

| Name | Type | Description |
| ---- | ---- | ----------- |
| `list_synthetics_monitors` | Tool | List Synthetic monitors. Args: `target_account_id` (optional). |
| `create_simple_browser_monitor` | Tool | Create a simple browser monitor. Args: `monitor_name` (str), `url` (str), `locations` (list), `period` (default `EVERY_15_MINUTES`), `status` (default `ENABLED`), `target_account_id`, `tags`. |

Monitor details are available via `get_entity_details` using the monitor's GUID.

### Alerts (`features/alerts.py`)

| Name | Type | Description |
| ---- | ---- | ----------- |
| `list_alert_policies` | Tool | List alert policies. Args: `target_account_id`, `policy_name_filter` (optional substring match). |
| `list_open_incidents` | Tool | List open incidents. Args: `target_account_id`, `priority` (`CRITICAL`/`WARNING`). |
| `acknowledge_alert_incident` | Tool | Acknowledge an incident. Args: `incident_id` (int), `target_account_id`, `message` (optional). |

## Contributing

Issues and pull requests are welcome. Fork, branch, commit, and open a PR.

## License

MIT — see the [LICENSE](LICENSE) file if present.
