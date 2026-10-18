"""Build a local SQLite lexicon from the included Google IME exports."""
from pathlib import Path
import csv, sqlite3, re, unicodedata, json, time

root = Path(__file__).resolve().parent.parent
destination = root / 'Resources' / 'medical.sqlite'
temporary = destination.with_suffix('.building')
if temporary.exists(): temporary.unlink()
db = sqlite3.connect(temporary)
db.execute('CREATE TABLE entries (reading TEXT NOT NULL, word TEXT NOT NULL, practical INTEGER NOT NULL, priority INTEGER NOT NULL, PRIMARY KEY(reading,word)) WITHOUT ROWID')
stats = {}
for filename, practical in [('base.txt', 0), ('practical.txt', 1)]:
    added = 0
    with (root / 'DictionarySources' / filename).open(encoding='utf-8-sig', newline='') as stream:
        for row in csv.reader(stream, delimiter='\t', quoting=csv.QUOTE_NONE):
            reading, word, part = row[:3]
            if part in {'サジェストのみ', '抑制単語'}: continue
            reading = unicodedata.normalize('NFC', reading)
            if not re.fullmatch('[ぁ-ゖー]+', reading) or reading.startswith('ー'): continue
            if not word or any(c in word for c in '\r\n\t'): continue
            before = db.total_changes
            db.execute('INSERT OR IGNORE INTO entries VALUES (?,?,?,?)', (reading, word, practical, practical))
            added += db.total_changes - before
    stats[filename] = added
db.commit()
assert db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
def candidates(reading, practical):
    exact = db.execute('SELECT word FROM entries WHERE reading=? AND practical<=? ORDER BY priority,word LIMIT 30', (reading,practical)).fetchall()
    prefix = db.execute('SELECT word FROM entries WHERE reading>? AND reading<? AND practical<=? ORDER BY priority,length(reading),reading,word LIMIT 30', (reading, reading+'\U0010ffff',practical)).fetchall()
    return list(dict.fromkeys(x[0] for x in exact+prefix))[:30]
checks = {
    'ちるぜぱちど': 'チルゼパチド',
    'れかねまぶ': 'レカネマブ',
    'がんげのむいりょう': 'がんゲノム医療',
    'こびっど': 'COVID-19',
    'りきっどばいおぷしー': 'リキッドバイオプシー',
}
for reading, expected in checks.items():
    assert expected in candidates(reading,0), (reading,expected)
assert any('チルゼパチド' == x for x in candidates('ちるぜぱ',0))
assert not candidates('ぬぬぬぬぬぬ',1)
assert not db.execute('SELECT 1 FROM entries WHERE practical NOT IN (0,1)').fetchone()
practical_only = db.execute('SELECT reading,word FROM entries WHERE practical=1 LIMIT 1').fetchone()
assert practical_only
assert practical_only[1] not in candidates(practical_only[0],0)
assert practical_only[1] in candidates(practical_only[0],1)
start = time.perf_counter()
for _ in range(20): candidates('か',1)
stats['single_kana_search_ms_on_build_PC'] = round((time.perf_counter()-start)*1000/20,2)
stats['prefix_query_plan'] = db.execute('EXPLAIN QUERY PLAN SELECT word FROM entries WHERE reading>? AND reading<?',('か','か\U0010ffff')).fetchall()
stats['total_entries'] = db.execute('SELECT count(*) FROM entries').fetchone()[0]
stats['unique_words'] = db.execute('SELECT count(DISTINCT word) FROM entries').fetchone()[0]
db.execute('VACUUM')
db.close()
temporary.replace(destination)
stats['database_bytes'] = destination.stat().st_size
stats['validation'] = 'SQLite integrity, exact and prefix search, exclusion of practical terms by default; passed'
stats['iOS_compilation_and_device_testing'] = 'Not run: macOS/Xcode and iPhone are not available in this environment'
(root/'Validation.json').write_text(json.dumps(stats,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(stats,ensure_ascii=False,indent=2))
