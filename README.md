# RTK Token Savings

An Omarchy bar widget that exposes the statistics collected by [`rtk gain`](https://github.com/rtk-ai/rtk).

## Features

- Total commands, input/output tokens, saved tokens, execution time, and efficiency.
- Top commands with count, savings, average efficiency, and execution time.
- Daily activity for the seven most recent days.
- Weekly and monthly summaries.
- Parse failures, recovery rate, estimated monthly quota, and preserved quota.
- Automatic refresh every 60 seconds and right-click manual refresh.

## Requirements

- Omarchy shell with bar-widget plugin support.
- `rtk` installed and initialized for the user.
- `python3` for combining the RTK output.

The widget reads the global RTK tracking database. It does not collect or transmit any additional data.

## Installation

Add the plugin through Omarchy's plugin manager:

```bash
omarchy plugin add https://github.com/pisolutions-es/rtk-ai-omarchy.git --enable
```

If needed, move the widget to the right section of `~/.config/omarchy/shell.json`:

```json
{
  "id": "io.github.jk.rtk-gain"
}
```

Omarchy Shell hot-reloads user plugin files. If the widget does not appear, restart the shell:

```bash
omarchy restart shell
```

## Removal

Remove the plugin through Omarchy's plugin manager:

```bash
omarchy plugin remove io.github.jk.rtk-gain
```

If the widget was manually added to the bar layout, remove its `io.github.jk.rtk-gain` entry from `~/.config/omarchy/shell.json` as well. Restart the shell if necessary:

```bash
omarchy restart shell
```

Removal only deletes the plugin files. It does not delete or modify RTK's tracking database.

## Development

Validate the manifest, collector, and QML before submitting changes:

```bash
python3 -m json.tool manifest.json >/dev/null
bash -n scripts/collect.sh
qmllint BarWidget.qml
bash scripts/collect.sh | python3 -m json.tool >/dev/null
```

The collector returns structured error JSON when the RTK tracking database is unavailable, so the widget can show an actionable error instead of stale values.

## License

MIT. See [LICENSE](LICENSE).
