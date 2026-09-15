import json
import os
import re
import sys

# Maximum characters allowed per line in Popotan's text box
MAX_LINE_LEN = 36


def sanitize_hungarian(text):
    """Replaces characters missing from English font patches (CP1252)."""
    if not text:
        return text
    charmap = {"ő": "ö", "Ő": "Ö", "ű": "ü", "Ű": "Ü"}
    for orig, sub in charmap.items():
        text = text.replace(orig, sub)
    return text


def wrap_sentence(sentence, max_len=MAX_LINE_LEN):
    """Wraps text with #cr0 tags without breaking words."""
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


def process_popotan_string(text):
    """Protects #p/#pp button prompts while wrapping Hungarian text."""
    if not text:
        return text

    # Convert unsupported Hungarian characters for font patch
    text = sanitize_hungarian(text)

    # Clean off any truncated tags at the end of lines
    text = re.sub(r"#(c|cr|p)?$", "", text)

    # Split string by button tags (#p, #pp, #p0, #cr0) so they aren't damaged
    tag_pattern = r"(#(?:pp|p\d*|cr\d*|c\d*))"
    parts = re.split(tag_pattern, text)

    processed_parts = []
    for part in parts:
        if re.match(tag_pattern, part):
            # Keep control tags exactly as they are
            processed_parts.append(part)
        else:
            # Word-wrap the Hungarian text
            if part.strip():
                processed_parts.append(wrap_sentence(part))
            else:
                processed_parts.append(part)

    return "".join(processed_parts)


def main():
    input_file = None

    # Auto-detect JSON file in the same directory
    if len(sys.argv) > 1:
        input_file = sys.argv[1]
    else:
        files = [
            f
            for f in os.listdir(".")
            if f.endswith(".json") and not f.endswith("_FIXED.json")
        ]
        if files:
            input_file = files[0]

    if not input_file or not os.path.exists(input_file):
        print(
            "ERROR: Couldn't find a JSON file. Place this script in your game folder!"
        )
        input("\nPress Enter to exit...")
        return

    print(f"Processing Popotan text file: {input_file}")

    try:
        with open(input_file, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        print(f"ERROR reading file: {e}")
        input("\nPress Enter to exit...")
        return

    repaired_data = {}
    count = 0

    # Process standard Key-Value JSON
    if isinstance(data, dict):
        for jp, hu in data.items():
            if not hu or not hu.strip():
                repaired_data[jp] = jp  # Fill blank lines with Japanese
            else:
                repaired_data[jp] = process_popotan_string(hu)
                count += 1

    # Process Array-based JSON
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
                    if not entry[dst_key] or not entry[dst_key].strip():
                        entry[dst_key] = entry[src_key]
                    else:
                        entry[dst_key] = process_popotan_string(entry[dst_key])
                        count += 1
            repaired_data.append(entry)

    base_name, ext = os.path.splitext(input_file)
    output_file = f"{base_name}_FIXED{ext}"

    # Save cleanly with UTF-8
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(repaired_data, f, ensure_ascii=False, indent=2)

    print("\nSUCCESS!")
    print(f"Fixed {count} sentences.")
    print(f"Protected button tags (#p/#pp) & fixed line breaks (#cr0).")
    print(f"Saved working output as: {output_file}")
    input("\nPress Enter to exit...")


if __name__ == "__main__":
    main()