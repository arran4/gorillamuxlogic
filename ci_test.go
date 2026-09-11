package gorillamuxlogic_test

import (
	"os/exec"
	"testing"
)

func TestCIRoutingAndReleasePreconditions(t *testing.T) {
	cmd := exec.Command(".github/scripts/test_ci.sh")
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("CI routing and release precondition test suite failed: %v\nOutput:\n%s", err, string(output))
	}
}
