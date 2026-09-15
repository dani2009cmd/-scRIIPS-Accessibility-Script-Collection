import json
import os
import re
import sys

MAX_LINE_LENGTH = 38  # Adjust line limit if needed


def auto_wrap_and_clean(text, max_len=MAX_LINE_LENGTH):
    if not text:
        return text

    # Remove broken tags at the end of lines
    text = re.sub(r"#c(r)?$", "", text)

    segments = text.split("#cr0")
    wrapped_segments = []

    for segment in segments:
        words = segment.split(" ")
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

        wrapped_segments.append("#cr0".join(lines))

    return "#cr0".join(wrapped_segments)


def main():
    input_file = None

    # Check if a file was dragged and dropped directly onto the script
    if len(sys.argv) > 1:
        input_file = sys.argv[1]
    else:
        # Automatically find the first .json file in the folder
        json_files = [
            f
            for f in os.listdir(".")
            if f.endswith(".json") and not f.endswith("_fixed.json")
        ]
        if json_files:
            input_file = json_files[0]

    if not input_file or not os.path.exists(input_file):
        print("ERROR: No JSON file found in this folder!")
        input("\nPress Enter to exit...")
        return

    print(f"Processing file: {input_file}")

    try:
        with open(input_file, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        print(f"ERROR reading JSON file: {e}")
        input("\nPress Enter to exit...")
        return

    repaired_data = {}
    fixed_count = 0
    empty_count = 0

    if isinstance(data, dict):
        for jp_text, hu_text in data.items():
            if not hu_text or hu_text.strip() == "":
                repaired_data[jp_text] = jp_text
                empty_count += 1
            else:
                repaired_data[jp_text] = auto_wrap_and_clean(hu_text)
                fixed_count += 1

    elif isinstance(data, list):
        repaired_data = []
        for entry in data:
            if isinstance(entry, dict):
                src_key = next(
                    (
                        k
                        for k in ["src", "original", "jp", "key"]
                        if k in entry
                    ),
                    None,
                )
                dst_key = next(
                    (
                        k
                        for k in ["dst", "translation", "hu", "value"]
                        if k in entry
                    ),
                    None,
                )

                if src_key and dst_key:
                    if not entry[dst_key] or entry[dst_key].strip() == "":
                        entry[dst_key] = entry[src_key]
                        empty_count += 1
                    else:
                        entry[dst_key] = auto_wrap_and_clean(entry[dst_key])
                        fixed_count += 1
            repaired_data.append(entry)

    base_name, ext = os.path.splitext(input_file)
    output_file = f"{base_name}_fixed{ext}"

    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(repaired_data, f, ensure_ascii=False, indent=2)

    print("\nSUCCESS!")
    print(f"Fixed {fixed_count} sentences.")
    print(f"Filled {empty_count} missing lines to prevent game crashes.")
    print(f"Saved new file as: {output_file}")
    input("\nPress Enter to exit...")


if __name__ == "__main__":
    main()