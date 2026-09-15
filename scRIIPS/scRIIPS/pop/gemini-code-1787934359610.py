import json
import os
import re
import sys
import traceback

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
os.chdir(SCRIPT_DIR)
LOG_FILE = os.path.join(SCRIPT_DIR, "LOG.txt")


def log(message):
    print(message)
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(message + "\n")


with open(LOG_FILE, "w", encoding="utf-8") as f:
    f.write("--- POPOTAN TRANSLATION REPAIR LOG ---\n")


def clean_hungarian(text):
    # Skip non-string values like numbers or booleans
    if not isinstance(text, str):
        return text

    charmap = {"ő": "ö", "Ő": "Ö", "ű": "ü", "Ű": "Ü"}
    for orig, sub in charmap.items():
        text = text.replace(orig, sub)
    return text


def wrap_text(sentence, max_len=36):
    if not isinstance(sentence, str):
        return sentence

    words = sentence.split(" ")
    lines = []
    current_line = []
    current_len = 0

    for word in words:
        if current_len + len(word) + (1 if current_line else 0) > max_len:
            if current_line:
                lines.append(" ".join(current_line))
            current_line = [word]
            current_len = len(word)
        else:
            current_line.append(word)
            current_len += len(word) + (1 if len(current_line) > 1 else 0)

    if current_line:
        lines.append(" ".join(current_line))

    return "#cr0".join(lines)


def process_string(text):
    # Safety check for non-string JSON values
    if not isinstance(text, str):
        return text

    text = clean_hungarian(text)
    text = re.sub(r"#(c|cr|p)?$", "", text)

    tag_pattern = r"(#(?:pp|p\d*|cr\d*|c\d*))"
    parts = re.split(tag_pattern, text)

    out = []
    for part in parts:
        if re.match(tag_pattern, part):
            out.append(part)
        elif part.strip():
            out.append(wrap_text(part))
        else:
            out.append(part)
    return "".join(out)


def main():
    try:
        log(f"Working Directory: {SCRIPT_DIR}")

        json_files = [
            f
            for f in os.listdir(SCRIPT_DIR)
            if f.endswith(".json") and "FIXED" not in f
        ]

        if not json_files:
            log("ERROR: No .json file found in this folder!")
            return

        target_file = json_files[0]
        log(f"Found target file: {target_file}")

        file_path = os.path.join(SCRIPT_DIR, target_file)
        with open(file_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        log("JSON loaded successfully. Processing lines...")

        repaired = {}
        count = 0

        if isinstance(data, dict):
            for jp, hu in data.items():
                repaired[jp] = process_string(hu) if hu else jp
                count += 1
        elif isinstance(data, list):
            repaired = []
            for entry in data:
                if isinstance(entry, dict):
                    src_k = next(
                        (
                            k
                            for k in ["src", "original", "jp", "key"]
                            if k in entry
                        ),
                        None,
                    )
                    dst_k = next(
                        (
                            k
                            for k in ["dst", "translation", "hu", "value"]
                            if k in entry
                        ),
                        None,
                    )
                    if src_k and dst_k:
                        entry[dst_k] = (
                            process_string(entry[dst_k])
                            if entry[dst_k]
                            else entry[src_k]
                        )
                        count += 1
                repaired.append(entry)

        out_name = os.path.join(
            SCRIPT_DIR,
            f"{os.path.splitext(target_file)[0]}_FIXED.json",
        )
        with open(out_name, "w", encoding="utf-8") as f:
            json.dump(repaired, f, ensure_ascii=False, indent=2)

        log(f"SUCCESS! Processed {count} items safely.")
        log(f"Saved output to: {out_name}")

    except Exception as e:
        log("CRITICAL ERROR OCCURRED:")
        log(traceback.format_exc())


if __name__ == "__main__":
    main()
    print("\nCheck LOG.txt in your folder to confirm completion.")
    input("Press Enter to exit...")