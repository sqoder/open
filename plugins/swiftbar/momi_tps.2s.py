#!/usr/bin/env python3
# <xbar.title>momi - AI Token Speed</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>momi</xbar.author>
# <xbar.desc>Real-time AI Token generation speed monitor</xbar.desc>

import glob, os, json, datetime

brain_dir = os.path.expanduser("~/.gemini/antigravity/brain")
files = glob.glob(brain_dir + "/*/.system_generated/logs/transcript.jsonl")

if not files:
    print("⚡ -- tok/s")
    print("---")
    print("未找到活动会话日志")
    exit(0)

newest_file = max(files, key=os.path.getmtime)
file_mod_time = os.path.getmtime(newest_file)
is_generating = (datetime.datetime.now().timestamp() - file_mod_time) < 2.0

try:
    with open(newest_file, "r", encoding="utf-8") as f:
        lines = [line.strip() for line in f if line.strip()]
        steps = [json.loads(l) for l in lines]
except Exception:
    print("⚡ -- tok/s")
    exit(0)

records = []
for i, step in enumerate(steps):
    if step.get("source") == "MODEL" and step.get("type") == "PLANNER_RESPONSE":
        out_tokens = step.get("output_tokens") or 0
        t_start_str = step.get("created_at")
        if not t_start_str:
            continue
        try:
            t_start = datetime.datetime.fromisoformat(t_start_str.replace("Z", "+00:00"))
        except Exception:
            continue
        
        step_idx = step.get("step_index", i)
        
        if i + 1 < len(steps):
            next_step = steps[i + 1]
            if next_step.get("type") in ("GENERIC", "MODEL", "TOOL"):
                t_end_str = next_step.get("created_at")
                if t_end_str:
                    try:
                        t_end = datetime.datetime.fromisoformat(t_end_str.replace("Z", "+00:00"))
                        dur = max(0.5, (t_end - t_start).total_seconds())
                        tps = out_tokens / dur
                        records.append((step_idx, out_tokens, dur, tps))
                    except Exception:
                        pass
        else:
            mod_dt = datetime.datetime.fromtimestamp(file_mod_time, tz=datetime.timezone.utc)
            dur = max(0.5, (mod_dt - t_start).total_seconds())
            if out_tokens > 0:
                tps = out_tokens / dur
                records.append((step_idx, out_tokens, dur, tps))

if records:
    last = records[-1]
    last_tps = last[3]
    if is_generating:
        print(f"⚡ {last_tps:.1f} t/s (生成中) | color=#FF9500")
    else:
        print(f"⚡ {last_tps:.1f} tok/s | color=#30D158")
    print("---")
    print("⚡ momi · AI 实时测速仪 | size=14 bold=true")
    print(f"当前速度: {last_tps:.1f} tokens/s | color=#30D158 bold=true")
    print(f"上次耗时: {last[2]:.1f}s · {last[1]} tokens")
    print(f"会话 ID: {os.path.basename(os.path.dirname(os.path.dirname(os.path.dirname(newest_file))))}")
    print("---")
    print("📊 最近生成记录:")
    for r in list(reversed(records[-5:])):
        print(f"  • {r[1]} tok · {r[2]:.1f}s → {r[3]:.1f} tok/s | font=Menlo size=11")
else:
    print("⚡ 0.0 tok/s")
    print("---")
    print("暂无已完成的生成记录")

print("---")
print("🔄 刷新 | refresh=true")
print(f"📂 打开日志目录 | bash=/usr/bin/open param1='{os.path.dirname(newest_file)}' terminal=false")
