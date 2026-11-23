#!/bin/bash
# Installs Carnama pre-push hook for all developers (Law 21)
HOOK_DIR=".git/hooks"
HOOK_FILE="$HOOK_DIR/pre-push"

cat > "$HOOK_FILE" << 'EOF'
#!/bin/bash
# Carnama Pre-Push Hook — Law 21 Mandatory
# Runs before every git push. Broken code never reaches remote.

echo "🔍 Running pre-push checks..."

echo "📐 Format check..."
dart format --set-exit-if-changed . || exit 1

echo "🔬 Static analysis..."
flutter analyze --fatal-infos || exit 1

echo "🧪 Running governance check..."
dart run tool/governance.dart || exit 1

echo "🧪 Running core tests..."
flutter test test/core/ || exit 1

echo "🧪 Running wiring tests..."
flutter test test/wiring/ || exit 1

echo "✅ All pre-push checks passed!"
EOF

chmod +x "$HOOK_FILE"
echo "✅ Pre-push hook installed at $HOOK_FILE"