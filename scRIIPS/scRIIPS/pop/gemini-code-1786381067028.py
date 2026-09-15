import json

CACHE_FILE = "windows_translation_cache.json"

def fix_translation_cache():
    with open(CACHE_FILE, "r", encoding="utf-8") as f:
        cache = json.load(f)

    # Map existing non-empty translations with space normalization
    normalized_map = {}
    for key, val in cache.items():
        if isinstance(val, str) and val.strip():
            norm_key = key.replace(" ", " ")
            normalized_map[norm_key] = val

    fixed_empty = 0
    shortened_records = 0

    # Process all cache entries
    for key, val in list(cache.items()):
        if isinstance(val, str):
            # Fill empty full-width space duplicate keys
            if not val.strip():
                norm_key = key.replace(" ", " ")
                if norm_key in normalized_map:
                    val = normalized_map[norm_key]
                    cache[key] = val
                    fixed_empty += 1

            # Clamp line lengths to dialogue limits across #cr0 breaks
            if val.strip():
                delimiter = "#cr0" if "#cr0" in val else "\n"
                lines = val.split(delimiter)
                new_lines = []
                was_shortened = False

                for line in lines:
                    if len(line) > 24:
                        new_lines.append(line[:24].strip())
                        was_shortened = True
                    else:
                        new_lines.append(line)

                if was_shortened:
                    cache[key] = delimiter.join(new_lines)
                    shortened_records += 1

    with open(CACHE_FILE, "w", encoding="utf-8") as f:
        json.dump(cache, f, ensure_ascii=False, indent=2)

    print(f"Filled {fixed_empty} empty duplicate keys.")
    print(f"Clamped {shortened_records} lines exceeding buffer bounds.")

if __name__ == "__main__":
    fix_translation_cache()