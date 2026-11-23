// Gate (d) boot probe.
//
// `firebase emulators:exec` starts the requested emulators and then runs this
// script. Firestore refuses to boot when `firestore.rules` does not compile, and
// the CLI then exits non-zero — so the value of this script is that it gives the
// emulator something to run at all. It proves the rules file loads in the real
// emulator; it deliberately proves nothing about rule semantics.
//
// Kept dependency-free and side-effect-free so it cannot fail for its own reasons
// and mask a genuine emulator problem.

const port = process.env.FIRESTORE_EMULATOR_HOST ?? '(unset FIRESTORE_EMULATOR_HOST)';

console.log(`emulator-boot-probe: firing after emulator startup, host=${port}`);

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  // The CLI always exports this for the wrapped script; its absence means we were
  // run outside `emulators:exec` and this gate would be proving nothing.
  console.error('emulator-boot-probe: FIRESTORE_EMULATOR_HOST is not set');
  process.exit(1);
}
