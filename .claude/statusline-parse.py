#!/usr/bin/env python3
import sys, json, time


def fmt_k(n):
    if n is None:
        return ""
    if n >= 1_000_000:
        return f"{n/1_000_000:.1f}M"
    if n >= 1_000:
        return f"{n/1_000:.1f}k"
    return str(n)


try:
    d = json.loads(sys.argv[1])
    model = d.get("model", {}).get("display_name", "Unknown")
    thinking = str(d.get("thinking", {}).get("enabled", False)).lower()
    effort = d.get("effort", {}).get("level", "")
    cw = d.get("context_window", {})
    cu = cw.get("current_usage", {})

    inp = cu.get("input_tokens")
    out = cu.get("output_tokens")
    cwr = cu.get("cache_creation_input_tokens", 0) or 0
    crd = cu.get("cache_read_input_tokens", 0) or 0

    total_in = (inp or 0) + cwr + crd

    # Context window: used vs max
    ctx_used = (
        cw.get("used_tokens") or cw.get("used") or (total_in if total_in else None)
    )
    ctx_max = (
        cw.get("max_tokens") or cw.get("total_tokens") or cw.get("context_window_size")
    )
    # Fallback: derive max from percentage
    if ctx_max is None and ctx_used is not None:
        pct = cw.get("used_percentage")
        if pct and float(pct) > 0:
            ctx_max = round(ctx_used / (float(pct) / 100))

    # Rate limits
    def fmt_reset(ts):
        if ts is None:
            return ""
        secs = int(ts) - int(time.time())
        if secs <= 0:
            return "now"
        h, m = divmod(secs // 60, 60)
        return f"{h}h{m:02d}m" if h else f"{m}m"

    rl = d.get("rate_limits", {})
    h5 = rl.get("five_hour", {})
    w7 = rl.get("seven_day", {})
    h5_pct = h5.get("used_percentage")
    w7_pct = w7.get("used_percentage")
    h5_pct_fmt = f"{round(float(h5_pct))}%" if h5_pct is not None else ""
    w7_pct_fmt = f"{round(float(w7_pct))}%" if w7_pct is not None else ""
    h5_reset_fmt = fmt_reset(h5.get("resets_at"))
    w7_reset_fmt = fmt_reset(w7.get("resets_at"))

    ctx_used_fmt = fmt_k(ctx_used)
    ctx_max_fmt = fmt_k(ctx_max)
    in_fmt = fmt_k(total_in) if total_in else ""
    out_fmt = fmt_k(out)

    sep = "\x01"
    print(
        sep.join(
            [
                model,
                thinking,
                effort,
                ctx_used_fmt,
                ctx_max_fmt,
                in_fmt,
                out_fmt,
                h5_pct_fmt,
                h5_reset_fmt,
                w7_pct_fmt,
                w7_reset_fmt,
            ]
        )
    )
except Exception as e:
    print("\x01".join(["Unknown", "false", "", "", "", "", "", "", ""]))
