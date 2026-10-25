#!/bin/bash
# 一键把本地改动同步到 GitHub Pages
# 前提：本机钥匙串已存 github.com 的账号密码（security find-internet-password -s github.com -a Li6808 -w）
set -e
cd "$(dirname "$0")"
REPO="Li6808/canteen-stock-calc"
PW=$(security find-internet-password -s github.com -a "Li6808" -w)

# 1) 提交本地改动
git add -A
git -c user.name="Teacher Assistant" -c user.email="teacher@assistant.local" \
    commit -m "feat: 食堂出库计算器

按周食谱自动计算每日出库量，早晚餐合并一段、午餐（营养午餐）单独一段标色。

核心规则：
- 人数分两套：工作日 800 / 周末 200，可分别修改
- 各餐就餐人数占比：早 35% / 午 100% / 晚 65%
- 油按桶计，每天 4 桶（早1+午2+晚1），不随人数变化
- 换算：每份克数 × 该餐实际就餐人数 ÷ 500 = 斤
- 周末不设营养午餐，三餐合并为一段

适配：手机端响应式，可添加到主屏幕（PWA）" || echo "(无改动，跳过提交)"

# 2) 通过 Contents API 推送到 GitHub
python3 - "$PW" "$REPO" << 'PYEOF'
import base64, json, urllib.request, urllib.error, sys, os, urllib.parse
pw, repo = sys.argv[1], sys.argv[2]
auth = base64.b64encode(f"Li6808:{pw}".encode()).decode()
H = {"Authorization": "Basic "+auth, "User-Agent": "WorkBuddy",
     "Accept": "application/vnd.github+json", "Content-Type": "application/json"}
def api(path, method="GET", data=None):
    r = urllib.request.Request("https://api.github.com"+path, method=method, headers=H,
                              data=json.dumps(data).encode() if data else None)
    try:
        return json.load(urllib.request.urlopen(r, timeout=40))
    except urllib.error.HTTPError as e:
        if e.code == 404: return None
        raise
files = [f for f in sorted(os.listdir(".")) if f != ".git" and not os.path.isdir(f)]
for fn in files:
    b64 = base64.b64encode(open(fn,'rb').read()).decode()
    q = urllib.parse.quote(fn)
    ex = api(f"/repos/{repo}/contents/{q}")
    payload = {"message": f"feat: 食堂出库计算器（{fn}）", "content": b64, "branch": "main"}
    if ex: payload["sha"] = ex["sha"]
    api(f"/repos/{repo}/contents/{q}", "PUT", payload)
    print("  ✅", fn)
print("✅ 已推送")
PYEOF

# 3) 触发 Pages 重建
python3 - "$PW" "$REPO" << 'PYEOF'
import base64, json, urllib.request, sys
pw, repo = sys.argv[1], sys.argv[2]
auth = base64.b64encode(f"Li6808:{pw}".encode()).decode()
H = {"Authorization": "Basic "+auth, "User-Agent": "WorkBuddy", "Accept": "application/vnd.github+json"}
r = urllib.request.Request(f"https://api.github.com/repos/{repo}/pages/builds/latest",
                           headers=H, method="POST")
try:
    d = json.load(urllib.request.urlopen(r, timeout=25))
    print("✅ Pages 重建已触发:", d.get("status"))
except Exception as e:
    print("（Pages 重建触发:", e, "）")
PYEOF

echo ""
echo "线上地址：https://li6808.github.io/canteen-stock-calc/"
