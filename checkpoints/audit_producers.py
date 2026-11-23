"""Inventory every client write to a collection whose rules are already ACTIVE.

`update()` is excluded on purpose: tenantOk() on an update compares the EXISTING
document, so an update without `tenantId` is correct once the document carries it.
Creates (`set` without merge / `add`) and full `set`s are the ones that must carry
the key.
"""
import io
import os
import re

ACTIVE = set("""analyticsEvents branches carts deletion_requests driverLocations
locations loyalty menus notification_queue notifications orders presence promo_usage
promoCodes promotions reservation_counters reservation_locks reservations users
waitlist waitlist_counters""".split())


def main():
    rows = []
    for root, _dirs, files in os.walk('core_app/lib'):
        for name in files:
            if not name.endswith('.dart'):
                continue
            path = os.path.join(root, name).replace(os.sep, '/')
            text = io.open(path, encoding='utf-8', errors='replace').read()
            text = text.replace('\r\n', '\n')
            # A document reference, not any `.set(` that happens to appear later
            # in the file: `.collection('x').doc(id).set(...)`.
            pattern = re.compile(
                r"\.collection\('([A-Za-z_]+)'\)\s*\.doc\([^)]*\)\s*(?:\.withConverter\([^)]*\)\s*)?\.(set|add)\(" )
            for match in pattern.finditer(text):
                coll = match.group(1)
                if coll not in ACTIVE:
                    continue
                tail = text[match.end():match.end() + 420]
                cut = tail.find(');')
                body = tail[:cut] if cut > 0 else tail
                line = text[:match.start()].count('\n') + 1
                rows.append((path, line, coll, 'tenantId' in body))
    rows.sort()
    missing = [r for r in rows if not r[3]]
    print('create/full-set sites on ACTIVE collections: %d, missing tenantId: %d'
          % (len(rows), len(missing)))
    for path, line, coll, ok in rows:
        tag = 'OK  ' if ok else 'MISSING'
        print('%s %s:%d %s' % (tag, path, line, coll))


main()
