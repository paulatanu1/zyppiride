#!/bin/bash

# Zyppi Ride E2E Test Runner Script
# Usage: ./run_e2e_tests.sh [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEVICE=""
VERBOSE=false
SUITE="all"
REPORT_DIR="test_reports"

# Print banner
print_banner() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}         ${GREEN}ZYPPI RIDE E2E TEST RUNNER${NC}                        ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}         Android Application Testing                       ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Print usage
usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -d, --device <id>    Specify device ID"
    echo "  -v, --verbose        Enable verbose output"
    echo "  -s, --suite <name>   Run specific test suite (auth, vehicle, user, driver, booking, database, all)"
    echo "  -r, --report <dir>   Specify report output directory (default: test_reports)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                   Run all tests on default device"
    echo "  $0 -s auth           Run only authentication tests"
    echo "  $0 -v -d emulator-1  Run verbose tests on specific device"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--device)
            DEVICE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -s|--suite)
            SUITE="$2"
            shift 2
            ;;
        -r|--report)
            REPORT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

print_banner

# Check Flutter installation
echo -e "${YELLOW}Checking Flutter installation...${NC}"
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}Flutter is not installed or not in PATH${NC}"
    exit 1
fi

flutter --version

# Check for connected devices
echo ""
echo -e "${YELLOW}Checking connected devices...${NC}"
flutter devices

# Create report directory
echo ""
echo -e "${YELLOW}Creating report directory: $REPORT_DIR${NC}"
mkdir -p "$REPORT_DIR"

# Get dependencies
echo ""
echo -e "${YELLOW}Getting dependencies...${NC}"
flutter pub get

# Build device argument
DEVICE_ARG=""
if [ -n "$DEVICE" ]; then
    DEVICE_ARG="-d $DEVICE"
fi

# Build verbose argument
VERBOSE_ARG=""
if [ "$VERBOSE" = true ]; then
    VERBOSE_ARG="--verbose"
fi

# Determine test file based on suite
TEST_FILE="integration_test/app_test.dart"
case $SUITE in
    auth)
        TEST_FILE="integration_test/tests/auth_test.dart"
        echo -e "${BLUE}Running Authentication Tests...${NC}"
        ;;
    vehicle)
        TEST_FILE="integration_test/tests/vehicle_management_test.dart"
        echo -e "${BLUE}Running Vehicle Management Tests...${NC}"
        ;;
    user)
        TEST_FILE="integration_test/tests/user_dashboard_test.dart"
        echo -e "${BLUE}Running User Dashboard Tests...${NC}"
        ;;
    driver)
        TEST_FILE="integration_test/tests/driver_dashboard_test.dart"
        echo -e "${BLUE}Running Driver Dashboard Tests...${NC}"
        ;;
    booking)
        TEST_FILE="integration_test/tests/booking_flow_test.dart"
        echo -e "${BLUE}Running Booking Flow Tests...${NC}"
        ;;
    database)
        TEST_FILE="integration_test/tests/database_test.dart"
        echo -e "${BLUE}Running Database Tests...${NC}"
        ;;
    all)
        echo -e "${BLUE}Running All E2E Tests...${NC}"
        ;;
    *)
        echo -e "${RED}Unknown test suite: $SUITE${NC}"
        usage
        exit 1
        ;;
esac

# Run tests
echo ""
echo -e "${GREEN}Starting E2E Tests...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

START_TIME=$(date +%s)

if flutter test $TEST_FILE $DEVICE_ARG $VERBOSE_ARG; then
    TEST_RESULT="PASSED"
    RESULT_COLOR=$GREEN
else
    TEST_RESULT="FAILED"
    RESULT_COLOR=$RED
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Print summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}                    ${RESULT_COLOR}TEST SUMMARY${NC}                           ${BLUE}║${NC}"
echo -e "${BLUE}╠════════════════════════════════════════════════════════════╣${NC}"
echo -e "${BLUE}║${NC}  Status:    ${RESULT_COLOR}$TEST_RESULT${NC}"
echo -e "${BLUE}║${NC}  Suite:     $SUITE"
echo -e "${BLUE}║${NC}  Duration:  ${DURATION}s"
echo -e "${BLUE}║${NC}  Reports:   $REPORT_DIR/"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# List generated reports
if [ -d "$REPORT_DIR" ]; then
    echo -e "${YELLOW}Generated Reports:${NC}"
    ls -la "$REPORT_DIR"/*.{html,json,md,xml} 2>/dev/null || echo "  No reports found yet"
fi

echo ""
echo -e "${GREEN}Test execution completed!${NC}"
echo ""

# Exit with appropriate code
if [ "$TEST_RESULT" = "PASSED" ]; then
    exit 0
else
    exit 1
fi
