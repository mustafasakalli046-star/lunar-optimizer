
import sqlite3
from pathlib import Path

schema_path = Path("database/schema.sql")
if not schema_path.exists() or schema_path.stat().st_size == 0:
    raise SystemExit("HATA: schema.sql bulunamadi veya bos.")

conn = sqlite3.connect(":memory:")
conn.execute("PRAGMA foreign_keys = ON")
conn.executescript(schema_path.read_text(encoding="utf-8"))

def must_fail(label, sql, values=()):
    try:
        conn.execute(sql, values)
    except sqlite3.IntegrityError:
        print(f"PASS: {label}")
        return
    raise AssertionError(f"FAIL: {label} kabul edilmemeliydi.")

# Geçerli temel kayıtlar
conn.execute("""
    INSERT INTO data_sources (name, provider)
    VALUES ('Test Source', 'Test')
""")
conn.execute("""
    INSERT INTO data_versions (source_id, data_status)
    VALUES (1, 'raw')
""")
conn.execute("""
    INSERT INTO regions (name, latitude, longitude)
    VALUES ('Test Region', 0, 0)
""")

# Geçersiz enlem reddedilmeli
must_fail(
    "Gecersiz koordinat reddediliyor",
    "INSERT INTO regions (name, latitude, longitude) VALUES (?, ?, ?)",
    ("Invalid Region", 100, 0)
)

# Olmayan kaynağa bağlı veri sürümü reddedilmeli
must_fail(
    "Olmayan kaynak icin foreign key",
    "INSERT INTO data_versions (source_id) VALUES (?)",
    (99999,)
)

# Güven değeri 0-1 aralığında olmalı
must_fail(
    "Gecersiz confidence degeri reddediliyor",
    """INSERT INTO measurements
       (version_id, variable_name, confidence)
       VALUES (1, 'test', 1.5)"""
)

# Sentetik veri sınıfı açıkça korunmalı
conn.execute("""
    INSERT INTO measurements
        (version_id, variable_name, value, record_class)
    VALUES (1, 'test_value', 42, 'synthetic')
""")
result = conn.execute("""
    SELECT record_class FROM measurements
    WHERE variable_name = 'test_value'
""").fetchone()[0]

assert result == "synthetic"
print("PASS: Sentetik veri siniflandirmasi")

print("\nBASARILI: Tum veri kisitlamasi testleri gecti.")
conn.close()
