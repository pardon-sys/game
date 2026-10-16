"""用户确认提示词后调用官方 Gemini；待审稿与原模块写回分开，密钥只来自环境 / .env。"""
import argparse
import ast
from concurrent.futures import ThreadPoolExecutor, as_completed
from copy import deepcopy
import hashlib
import importlib
import json
import os
from pathlib import Path
from pprint import pformat
import ssl
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
PROMPT = ROOT / "doc/siege_gemini_rewrite_prompt.md"
REVIEW = ROOT / "doc/siege_gemini_argon_review.json"
MODEL = "gemini-4-argon"
MODULES = ("gale_bear", "puppet_master")
CONTENT_FLAGS = ("高潮", "情欲", "性欲", "乳头", "阴道", "阴蒂", "阴茎", "勃起")
SCHEMA = {"type": "OBJECT", "properties": {"replacements": {"type": "ARRAY", "items": {
    "type": "OBJECT", "properties": {"id": {"type": "STRING"}, "text": {"type": "STRING"}},
    "required": ["id", "text"]}}}, "required": ["replacements"]}


def digest(text):
    return hashlib.sha256(text.encode()).hexdigest()


def source_data():
    result = {}
    hashes = {}
    for boss in MODULES:
        module = importlib.import_module(boss + "_text")
        hashes[boss] = digest(Path(module.__file__).read_text())
        result[boss] = {}
        for role in ("pink", "blue"):
            title, steps = module.cg_script(role)
            bundle = {"reaction": module.reaction(role), "cg": {"title": title, "steps": steps}}
            if boss == "puppet_master":
                bundle["towers"] = module.tower_reactions(role)
            result[boss][role] = json.loads(json.dumps(bundle, ensure_ascii=False))
    return result, hashes


def catalog(data):
    out = []
    def add(boss, role, path, value, kind):
        out.append({"id": "/".join([boss, role] + [str(v) for v in path]), "role": role,
                    "kind": kind, "context": "/".join([boss] + [str(v) for v in path]),
                    "text": value, "path": path, "boss": boss})
    def walk(boss, role, path, value, kind):
        if isinstance(value, str):
            add(boss, role, path, value, kind)
        elif isinstance(value, list):
            for i, item in enumerate(value):
                walk(boss, role, path + [i], item, kind)
        elif isinstance(value, dict):
            for key, item in value.items():
                if key not in {"name", "speaker", "emotion"}:
                    walk(boss, role, path + [key], item, kind)
    for boss, roles in data.items():
        for role, bundle in roles.items():
            walk(boss, role, ["reaction"], bundle["reaction"], "reaction")
            add(boss, role, ["cg", "title"], bundle["cg"]["title"], "cg_title")
            for i, row in enumerate(bundle["cg"]["steps"]):
                add(boss, role, ["cg", "steps", i, 1], row[1], "cg_narration" if row[0] == "N" else "cg_dialogue")
    return out


def validate(rows, replacements):
    ids = [r["id"] for r in replacements]
    expected = {r["id"] for r in rows}
    if len(ids) != len(set(ids)) or set(ids) != expected:
        raise ValueError("Model output must contain each original id exactly once")
    for row in replacements:
        text = row.get("text")
        if not isinstance(text, str) or not text.strip() or len(text) > 450:
            raise ValueError("Invalid or oversized replacement text: " + row["id"])
        if any(word in text for word in CONTENT_FLAGS):
            raise ValueError("Replacement requires content review: " + row["id"])
        if "portrait_words" in row["id"] and len(text) > 20:
            raise ValueError("Portrait caption must stay short: " + row["id"])


def generate():
    from dotenv import dotenv_values
    import certifi
    key = os.environ.get("GEMINI") or dotenv_values(ROOT / ".env").get("GEMINI")
    if not key:
        raise SystemExit("GEMINI is missing; no request sent")
    approved = PROMPT.read_text().split("## 提示词正文\n\n", 1)[1].split("\n## 随附输入的形式", 1)[0]
    data, hashes = source_data()
    rows = catalog(data)
    audit = {"model": MODEL, "prompt_sha256": digest(approved), "prompt": approved,
             "source_sha256": hashes, "input": data, "catalog": rows, "batches": [], "replacements": []}
    if REVIEW.exists():
        saved = json.loads(REVIEW.read_text())
        if saved["source_sha256"] != hashes or saved["prompt_sha256"] != digest(approved):
            raise SystemExit("Existing review has a different prompt or source; keep it for review")
        audit = saved
    received = {r["id"] for r in audit["replacements"]}
    batches = []
    for boss in MODULES:
        for role in ("pink", "blue"):
            speech = [r for r in rows if r["boss"] == boss and r["role"] == role and r["path"][0] != "cg" and r["id"] not in received]
            script = [r for r in rows if r["boss"] == boss and r["role"] == role and r["path"][0] == "cg" and r["id"] not in received]
            batches.extend(speech[i:i + 45] for i in range(0, len(speech), 45))
            if script:
                batches.append(script)  # 一个 CG 的全部旁白 / 台词同批，不把剧情割开。
    def request(batch):
        attachment = [{k: r[k] for k in ("id", "role", "kind", "context", "text")} for r in batch]
        body = {"contents": [{"role": "user", "parts": [{"text": approved},
                {"text": "当前文案附件：\n" + json.dumps(attachment, ensure_ascii=False)}]}],
                "generationConfig": {"responseMimeType": "application/json", "responseSchema": SCHEMA,
                                     "maxOutputTokens": 32768, "thinkingConfig": {"thinkingLevel": "LOW"}}}
        req = urllib.request.Request("https://generativelanguage.googleapis.com/v1beta/models/" + MODEL + ":generateContent",
              data=json.dumps(body, ensure_ascii=False).encode(),
              headers={"x-goog-api-key": key, "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=300, context=ssl.create_default_context(cafile=certifi.where())) as response:
                result = json.load(response)
        except urllib.error.HTTPError as error:
            raise RuntimeError("Google API HTTP status " + str(error.code)) from None
        except urllib.error.URLError as error:
            raise RuntimeError("Google API network error " + type(error.reason).__name__) from None
        candidate = result.get("candidates", [{}])[0]
        output = "".join(p.get("text", "") for p in candidate.get("content", {}).get("parts", []) if not p.get("thought"))
        replacements = json.loads(output).get("replacements", [])
        # 不合要求的输出不保存原句：恢复原项目句子，记录 id 供后续编辑审改。
        # 先校验完整 id，防止模型凭空添加条目或把其他段落写入源文案。
        originals = {r["id"]: r["text"] for r in batch}
        ids = [r.get("id") for r in replacements]
        if len(ids) != len(set(ids)) or set(ids) != set(originals):
            raise ValueError("Model output must contain each original id exactly once")
        discarded = []
        for row in replacements:
            value = row.get("text", "")
            if any(word in value for word in CONTENT_FLAGS) or ("portrait_words" in row["id"] and len(value) > 20):
                discarded.append(row["id"])
                row["text"] = originals[row["id"]]
        validate(batch, replacements)
        return {"boss": batch[0]["boss"], "role": batch[0]["role"], "modelVersion": result.get("modelVersion"),
                "finishReason": candidate.get("finishReason"), "usageMetadata": result.get("usageMetadata", {}),
                "discarded_output_ids": discarded, "replacements": replacements}
    failures = []
    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = {pool.submit(request, batch): batch for batch in batches}
        for future in as_completed(futures):
            try:
                batch = future.result()
            except Exception as error:
                failed = futures[future]
                failures.append({"ids": [r["id"] for r in failed], "error": type(error).__name__})
                print("Batch failed; other drafts will be kept:", failed[0]["boss"], failed[0]["role"], type(error).__name__, flush=True)
                continue
            audit["batches"].append(batch)
            audit["replacements"].extend(batch["replacements"])
            REVIEW.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n")
            print("Reviewed-format response:", batch["boss"], batch["role"], len(batch["replacements"]),
                  "restored original pending editorial review:", len(batch["discarded_output_ids"]), flush=True)
    if failures:
        audit["failed_batches"] = failures
        REVIEW.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n")
        raise SystemExit("Incomplete candidate saved; rerun generate to request only missing rows")
    validate(rows, audit["replacements"])
    print("Saved candidate text for editorial review:", len(rows), "entries; no source modules changed", flush=True)


def apply():
    audit = json.loads(REVIEW.read_text())
    current_prompt = PROMPT.read_text().split("## 提示词正文\n\n", 1)[1].split("\n## 随附输入的形式", 1)[0]
    if digest(current_prompt) != audit["prompt_sha256"]:
        raise SystemExit("Prompt changed since generation; confirm it before applying text")
    original, hashes = source_data()
    if hashes != audit["source_sha256"] or original != audit["input"]:
        raise SystemExit("Source changed since generation; refusing to overwrite")
    rows = catalog(original)
    validate(rows, audit["replacements"])
    revised = deepcopy(original)
    replacements = {r["id"]: r["text"] for r in audit["replacements"]}
    for row in rows:
        if row["path"][0] == "towers":
            continue  # 用户最后收紧范围：只改两个 Boss，敌塔的原反应保持不变。
        target = revised[row["boss"]][row["role"]]
        for step in row["path"][:-1]:
            target = target[step]
        target[row["path"][-1]] = replacements[row["id"]]
    for boss in MODULES:
        roles = revised[boss]
        path = ROOT / "tools/build" / (boss + "_text.py")
        tower_function = None
        if boss == "puppet_master":
            source = path.read_text()
            tree = ast.parse(source)
            tower_function = ast.get_source_segment(source, next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "tower_reactions"))
        text = '"""Gemini 4 Argon 重写后的定稿；保持原生成器接口。提示词与完整待审稿见 doc。"""\nfrom copy import deepcopy\n\n'
        text += 'STAGES = ("calm", "giggle", "helpless_1", "helpless_2")\n\n'
        text += "_REACTIONS = " + pformat({role: d["reaction"] for role, d in roles.items()}, width=112, sort_dicts=False) + "\n\n"
        text += "_CGS = " + pformat({role: d["cg"] for role, d in roles.items()}, width=112, sort_dicts=False) + "\n\n"
        text += "def reaction(who):\n    return deepcopy(_REACTIONS[who])\n\n\n"
        if boss == "puppet_master":
            text += tower_function + "\n\n\n"
        text += 'def cg_script(who):\n    script = _CGS[who]\n    return script["title"], deepcopy(script["steps"])\n'
        path.write_text(text)
    print("Applied reviewed text to two original source modules; run the three original generators next")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["generate", "apply"])
    args = parser.parse_args()
    if args.action == "generate":
        generate()
    else:
        apply()
