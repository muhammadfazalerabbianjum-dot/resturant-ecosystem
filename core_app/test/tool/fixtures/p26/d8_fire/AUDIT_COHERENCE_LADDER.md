# fixture ladder (p26 d8_fire)

## §1 connected rungs

| Chain | Status |
|---|---|
| fixture | ok |

## §2 MISSING STAIRS — surfaces with NO owning wave

| # | Severity | Unassigned surface | Size receipt | Why it matters |
|---|---|---|---|---|
| M-1 | HIGH | `a_screen.dart` | 10 lines | first hole |
| M-2 | MED | `b_screen.dart` | 20 lines | second hole |
| M-3 | LOW | `c_screen.dart` | 30 lines | third hole |
| M-4 | LOW | `d_screen.dart` | 40 lines | fourth hole |

## §5 Verdict

n/a for the fixture.

## §6 Corrected queue (renumbered, no hole left unassigned)

| Spec | Owns | Depends on |
|---|---|---|
| `p97_fixture_a` | M-1, M-2 | independent |
| `p96_ghost` | M-4 | independent |
