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

Clone this repository into the Omarchy user plugin directory:

```bash
git clone https://github.com/pisolutions-es/rtk-ai-omarchy.git ~/.config/omarchy/plugins/io.github.jk.rtk-gain
```

Then add the widget ID to the right section of `~/.config/omarchy/shell.json`:

```json
{
  "id": "io.github.jk.rtk-gain"
}
```

Omarchy Shell hot-reloads user plugin files. If the widget does not appear, restart the shell:

```bash
omarchy restart shell
```

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
