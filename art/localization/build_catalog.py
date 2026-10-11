"""Build standard Godot CSV translations from reviewable English/Chinese pairs."""
import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
entries = {}
english_values = {}
for source in sorted((ROOT / 'art/localization').glob('*.tsv')):
    for line_number, line in enumerate(source.read_text().splitlines(), 1):
        if not line or line.startswith('#'):
            continue
        english, chinese = line.split('\t', 1)
        english = english.replace('\\n', '\n').replace('\\t', '\t')
        chinese = chinese.replace('\\n', '\n').replace('\\t', '\t')
        if english in entries and entries[english] != chinese:
            raise ValueError(f'Conflicting translation: {source}:{line_number}: {english}')
        markers = r"%[-+0-9.]*[sdf]|%%"
        if re.findall(markers, english) != re.findall(markers, chinese):
            raise ValueError(f"Placeholder mismatch: {source}:{line_number}: {english}")
        entries[english] = chinese
# Existing symbolic keys keep working in old scenes and narration.
legacy = {'main_menu': {}, 'match': {}}
for name in legacy:
    with (ROOT / f'assets/translations/{name}.csv').open() as stream:
        for row in list(csv.reader(stream))[1:]:
            if len(row) > 1 and row[1] in entries:
                entries[row[0]] = entries[row[1]]
                english_values[row[0]] = row[1]
with (ROOT / 'assets/translations/ui.csv').open('w', newline='') as stream:
    writer = csv.writer(stream)
    writer.writerow(['keys', 'en', 'zh_CN'])
    for english, chinese in sorted(entries.items()):
        writer.writerow([english, english_values.get(english, english), chinese])
print(f'Wrote {len(entries)} translations')
