#!/bin/bash

# ============================================
# ZYPPI RIDE E2E TEST RUNNER
# ============================================

set -e

echo "═══════════════════════════════════════════"
echo "   ZYPPI RIDE E2E TEST RUNNER"
echo "═══════════════════════════════════════════"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
PLATFORM="android"
DEVICE=""
CLEAN_BUILD=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --android)
            PLATFORM="android"
            shift
            ;;
        --ios)
            PLATFORM="ios"
            shift
            ;;
        --device)
            DEVICE="$2"
            shift 2
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            echo "Usage: ./run_e2e_tests.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --android     Run on Android device/emulator (default)"
            echo "  --ios         Run on iOS device/simulator"
            echo "  --device ID   Specify device ID"
            echo "  --clean       Clean build before running"
            echo "  --verbose     Verbose output"
            echo "  --help        Show this help message"
            echo ""
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Navigate to project root
cd "$(dirname "$0")/../.."
PROJECT_ROOT=$(pwd)

echo "📁 Project root: $PROJECT_ROOT"
echo "📱 Platform: $PLATFORM"
echo ""

# Clean build if requested
if [ "$CLEAN_BUILD" = true ]; then
    echo -e "${YELLOW}🧹 Cleaning build...${NC}"
    flutter clean
    flutter pub get
    echo ""
fi

# Ensure dependencies are installed
echo "📦 Getting dependencies..."
flutter pub get

# Create test output directories with proper permissions
echo "📁 Creating test output directories..."
mkdir -p "$PROJECT_ROOT/test_results/screenshots" 2>/dev/null || true
mkdir -p "$PROJECT_ROOT/test_results/reports" 2>/dev/null || true

# Timestamp for reports
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
OUTPUT_FILE="$PROJECT_ROOT/test_results/reports/test_output_$TIMESTAMP.log"
JSON_REPORT="$PROJECT_ROOT/test_results/reports/e2e_report_$TIMESTAMP.json"
LATEST_JSON="$PROJECT_ROOT/test_results/reports/latest_report.json"
LATEST_HTML="$PROJECT_ROOT/test_results/reports/latest_report.html"

# Build command
BUILD_FLAGS="--dart-define=E2E_TEST_MODE=true"

if [ "$VERBOSE" = true ]; then
    BUILD_FLAGS="$BUILD_FLAGS --verbose"
fi

# Device selection
if [ -n "$DEVICE" ]; then
    DEVICE_FLAG="-d $DEVICE"
else
    DEVICE_FLAG=""
fi

echo ""
echo "═══════════════════════════════════════════"
echo "   RUNNING E2E TESTS"
echo "═══════════════════════════════════════════"
echo ""

# Run the tests and capture output
if [ "$PLATFORM" = "android" ]; then
    echo -e "${GREEN}🤖 Running on Android...${NC}"
    flutter test integration_test/e2e/e2e_main_test.dart \
        $BUILD_FLAGS \
        $DEVICE_FLAG \
        --no-pub 2>&1 | tee "$OUTPUT_FILE"
elif [ "$PLATFORM" = "ios" ]; then
    echo -e "${GREEN}🍎 Running on iOS...${NC}"
    flutter test integration_test/e2e/e2e_main_test.dart \
        $BUILD_FLAGS \
        $DEVICE_FLAG \
        --no-pub 2>&1 | tee "$OUTPUT_FILE"
fi

# Check exit code
TEST_EXIT_CODE=${PIPESTATUS[0]}

echo ""
echo "═══════════════════════════════════════════"

# Extract JSON report from output
echo "📄 Extracting test report..."
if grep -q "BEGIN_JSON_REPORT" "$OUTPUT_FILE"; then
    # Extract only valid JSON lines (filter out Flutter test progress output)
    sed -n '/BEGIN_JSON_REPORT/,/END_JSON_REPORT/p' "$OUTPUT_FILE" | \
        grep -v "BEGIN_JSON_REPORT" | \
        grep -v "END_JSON_REPORT" | \
        grep -v "flutter:" | \
        grep -v "^[0-9][0-9]:[0-9][0-9]" | \
        grep -v "^\[" | \
        grep -v "^Running" | \
        grep -v "^✅" | \
        grep -v "^═" | \
        grep -E '^\s*[\{\}\[\]"]|^\s*$' > "$JSON_REPORT"

    # Copy to latest
    cp "$JSON_REPORT" "$LATEST_JSON" 2>/dev/null || true

    echo -e "${GREEN}✅ JSON Report saved: $JSON_REPORT${NC}"

    # Generate HTML report with embedded JSON data
    echo "📄 Generating HTML report..."

    # Read JSON content and escape for embedding
    JSON_CONTENT=$(cat "$JSON_REPORT")

    cat > "$LATEST_HTML" << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>E2E Test Report - Zyppi Ride</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f5f5; color: #333; padding: 20px; }
        .container { max-width: 1000px; margin: 0 auto; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px; margin-bottom: 20px; }
        .header h1 { font-size: 24px; margin-bottom: 10px; }
        .summary { display: grid; grid-template-columns: repeat(4, 1fr); gap: 15px; margin-bottom: 20px; }
        .card { background: white; padding: 20px; border-radius: 10px; text-align: center; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .card.pass { border-left: 4px solid #4CAF50; }
        .card.fail { border-left: 4px solid #f44336; }
        .card h3 { font-size: 28px; margin-bottom: 5px; }
        .test-list { background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .test-item { display: flex; align-items: center; padding: 12px 20px; border-bottom: 1px solid #eee; }
        .test-item.pass { background: #f1f8e9; }
        .test-item.fail { background: #ffebee; }
        .status { width: 24px; height: 24px; border-radius: 50%; margin-right: 15px; display: flex; align-items: center; justify-content: center; color: white; font-size: 12px; }
        .status.pass { background: #4CAF50; }
        .status.fail { background: #f44336; }
        .test-name { flex: 1; }
        .duration { color: #999; font-size: 12px; }
        .error-msg { color: #f44336; font-size: 11px; margin-top: 4px; white-space: pre-wrap; max-height: 60px; overflow: auto; }
        pre { background: #f0f0f0; padding: 15px; border-radius: 5px; overflow-x: auto; font-size: 12px; margin-top: 20px; max-height: 400px; }
        .progress-bar { height: 8px; background: #e0e0e0; border-radius: 4px; margin-top: 10px; overflow: hidden; }
        .progress-fill { height: 100%; background: linear-gradient(90deg, #4CAF50, #8BC34A); transition: width 0.3s; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚗 Zyppi Ride E2E Test Report</h1>
            <p>Generated: $TIMESTAMP</p>
        </div>
        <div class="summary">
            <div class="card"><h3 id="total">-</h3><p>Total Tests</p></div>
            <div class="card pass"><h3 id="passed">-</h3><p>Passed</p></div>
            <div class="card fail"><h3 id="failed">-</h3><p>Failed</p></div>
            <div class="card"><h3 id="rate">-</h3><p>Pass Rate</p><div class="progress-bar"><div class="progress-fill" id="progress"></div></div></div>
        </div>
        <div class="test-list" id="results"></div>
        <details style="margin-top:20px"><summary style="cursor:pointer;padding:10px;background:#fff;border-radius:5px;">View Raw JSON</summary><pre id="json"></pre></details>
    </div>
    <script id="report-data" type="application/json">
$JSON_CONTENT
    </script>
    <script>
        try {
            const data = JSON.parse(document.getElementById('report-data').textContent);
            document.getElementById('total').textContent = data.summary?.totalTests || data.results?.length || 0;
            document.getElementById('passed').textContent = data.summary?.passedTests || data.results?.filter(r => r.passed).length || 0;
            document.getElementById('failed').textContent = data.summary?.failedTests || data.results?.filter(r => !r.passed).length || 0;
            const total = data.summary?.totalTests || data.results?.length || 1;
            const passed = data.summary?.passedTests || data.results?.filter(r => r.passed).length || 0;
            const rate = ((passed / total) * 100).toFixed(1);
            document.getElementById('rate').childNodes[0].textContent = rate + '%';
            document.getElementById('progress').style.width = rate + '%';

            const resultsDiv = document.getElementById('results');
            (data.results || []).forEach(r => {
                const div = document.createElement('div');
                div.className = 'test-item ' + (r.passed ? 'pass' : 'fail');
                let errHtml = '';
                if (r.errorMessage) {
                    const shortErr = r.errorMessage.split('\\n')[0].substring(0, 100);
                    errHtml = '<div class="error-msg">' + shortErr + '</div>';
                }
                div.innerHTML = '<div class="status ' + (r.passed ? 'pass' : 'fail') + '">' + (r.passed ? '✓' : '✗') + '</div>' +
                    '<div class="test-name"><strong>' + r.testName + '</strong><br><small style="color:#666">' + (r.category || '') + '</small>' + errHtml + '</div>' +
                    '<div class="duration">' + (r.duration || 0) + 'ms</div>';
                resultsDiv.appendChild(div);
            });

            document.getElementById('json').textContent = JSON.stringify(data, null, 2);
        } catch(e) {
            document.getElementById('results').innerHTML = '<div style="padding:20px;color:red;">Error parsing report: ' + e.message + '</div>';
        }
    </script>
</body>
</html>
HTMLEOF

    echo -e "${GREEN}✅ HTML Report saved: $LATEST_HTML${NC}"
else
    echo -e "${YELLOW}⚠️ No JSON report found in output${NC}"
fi

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}   ✅ ALL TESTS PASSED${NC}"
else
    echo -e "${RED}   ❌ SOME TESTS FAILED${NC}"
fi

echo "═══════════════════════════════════════════"
echo ""

# Display report locations
echo "📄 Reports available at:"
echo "   Log: $OUTPUT_FILE"
echo "   JSON: $LATEST_JSON"
echo "   HTML: $LATEST_HTML"
echo ""

# Open HTML report if on macOS
if [ "$(uname)" = "Darwin" ]; then
    if [ -f "$LATEST_HTML" ]; then
        echo "🌐 Opening HTML report..."
        open "$LATEST_HTML"
    fi
fi

exit $TEST_EXIT_CODE
