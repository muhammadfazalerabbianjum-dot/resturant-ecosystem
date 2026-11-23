#!/usr/bin/env bash
# P0-1 planted-failure proofs.
# Each block: plant a defect -> run the one gate -> capture its exit code ->
# revert -> verify the file is byte-identical to git HEAD again.
# Originals are kept under checkpoints/plants/ as evidence.
set -u
cd "<repo>" || exit 9
OUT=checkpoints/plants
mkdir -p "$OUT"

run_gate() { # $1=gate id  $2=log name  -> prints exit code
  cmd //c ".\\gate.cmd check --only=$1" >"$OUT/$2.log" 2>&1
  echo "$?"
}

echo "### [c] functions-build: type error in functions/src/access.ts"
cp core_app/functions/src/access.ts "$OUT/c.access.ts.orig"
printf '\n// P0-1 gate plant\nexport const gatePlantValue: number = "not-a-number";\n' >> core_app/functions/src/access.ts
c_exit=$(run_gate c c)
echo "c_exit=$c_exit"
git checkout -- core_app/functions/src/access.ts
git diff --quiet -- core_app/functions/src/access.ts && echo "c_reverted=clean" || echo "c_reverted=DIRTY"

echo "### [e] whitelabel-dry-run: required app block removed from client_config.json"
cp apps/halal_boyz/assets/client_config.json "$OUT/e.client_config.json.orig"
node -e "const fs=require('fs');const p='apps/halal_boyz/assets/client_config.json';const j=JSON.parse(fs.readFileSync(p,'utf8'));delete j.app;fs.writeFileSync(p,JSON.stringify(j,null,2));"
e_exit=$(run_gate e e)
echo "e_exit=$e_exit"
git checkout -- apps/halal_boyz/assets/client_config.json
git diff --quiet -- apps/halal_boyz/assets/client_config.json && echo "e_reverted=clean" || echo "e_reverted=DIRTY"

echo "### [b]+[f] gate-fast-tests + stub-scan: new tagged failing test carrying a stub marker"
cat > core_app/test/zz_gate_plant_test.dart <<'DART'
@Tags(['gate_fast'])
library;

// TODO: planted stub marker for gate (f)
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('planted failure', () {
    expect(1, 2);
  });
}
DART
b_exit=$(run_gate b b)
echo "b_exit=$b_exit"
f_exit=$(run_gate f f)
echo "f_exit=$f_exit"
rm -f core_app/test/zz_gate_plant_test.dart
[ -f core_app/test/zz_gate_plant_test.dart ] && echo "bf_reverted=NO" || echo "bf_reverted=clean"

echo "### [d] emulator-rules: invalid syntax appended to core_app/firestore.rules"
cp core_app/firestore.rules "$OUT/d.firestore.rules.orig"
printf '\n// P0-1 gate plant: deliberately invalid rules syntax\nmatch /zzGatePlantBroken/{id} {\n  allow read:\n}\n' >> core_app/firestore.rules
d_exit=$(run_gate d d)
echo "d_exit=$d_exit"
git checkout -- core_app/firestore.rules
git diff --quiet -- core_app/firestore.rules && echo "d_reverted=clean" || echo "d_reverted=DIRTY"

echo "### PLANT PROOF SUMMARY"
echo "c_exit=$c_exit (expect 1) | e_exit=$e_exit (expect 1) | b_exit=$b_exit (expect 1) | f_exit=$f_exit (expect 1) | d_exit=$d_exit (expect 1)"
