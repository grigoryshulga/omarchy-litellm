# LiteLLM for the Omarchy bar

Personal LiteLLM usage dashboard for the Omarchy shell. The bar shows the
percentage remaining from a daily-budget-based weekly spending limit. Its panel
shows daily and weekly spend meters, the Monday-to-Sunday reset, today's usage,
the last 30 days, and top models.

The plugin targets LiteLLM Proxy `1.86.1` and uses its documented API:

- `GET /key/info` for the virtual-key budget and limits;
- `GET /user/daily/activity` for personal daily aggregates. The paginated
  route is available to the virtual key, unlike the admin-only aggregated route
  in LiteLLM Proxy `1.86.1`.

## Install

```bash
omarchy plugin add https://github.com/grigoryshulga/omarchy-litellm.git --enable
```

For local development, Omarchy discovers the project when it is linked into
the user plugin directory:

```bash
ln -s ~/projects/personal/omarchy-litellm ~/.config/omarchy/plugins/gshulga.litellm
omarchy plugin enable gshulga.litellm
```

## Configuration

Create `~/.config/omarchy/litellm.json` with mode `0600`:

```json
{
  "baseUrl": "https://litellm.example.com",
  "secretKey": "LITELLM_VIRTUAL_KEY"
}
```

The API URL must use HTTPS. `secretKey` is the Bitwarden Secrets Manager key,
not the LiteLLM virtual key itself.

The collector uses the `x-litellm-api-key` request header. It never puts the
virtual key in a URL, the QML state file, or diagnostics.

## Bitwarden

The BWS machine-account token is read from the current process environment or
from one of these mode-`0600` files:

```text
~/.config/omarchy/litellm.env
~/.config/omarchy/jira.env
```

Either file can contain:

```text
BWS_ACCESS_TOKEN=...
BWS_SERVER_URL=https://your-bitwarden.example.com
```

The secret named by `secretKey` must be readable by that BWS machine account.
The virtual key itself is cached only in `/run/user/$UID/omarchy-litellm/`,
which is removed when the user session ends. The dashboard reads only the
secret-free aggregate cache at `~/.local/state/omarchy/litellm/data.json`.

## Usage and interactions

- Left click: open or close the dashboard.
- Middle click: refresh immediately.
- `r` or Enter in the dashboard: refresh immediately.
- `j`/`k`: scroll the dashboard.
- `Esc`: close it.

The widget refreshes every five minutes by default. The daily spending budget
defaults to `$50`; the weekly limit is calculated as seven daily budgets, or
`$350`, and resets every Monday. Change the daily budget through the Omarchy
plugin settings, or edit the widget entry in `shell.json`:

```json
{ "id": "gshulga.litellm", "refreshIntervalSec": 300, "dailyLimitUsd": 50 }
```

Existing inline `weeklyLimitUsd` settings are treated as their equivalent
daily budget during migration.

The weekly meter requires user-activity access. If the virtual key cannot read
that endpoint, the panel explains that detailed analytics are unavailable.

## Development

```bash
python3 -m unittest discover -s tests -v
python3 -m py_compile bin/omarchy-litellm-sync
qmllint Panel.qml Service.qml
omarchy plugin validate .
```

No LiteLLM key, BWS token, runtime secret cache, or local configuration belongs
in this repository.
