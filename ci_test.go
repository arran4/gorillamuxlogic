package gorillamuxlogic_test

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

func TestCIRoutingAndReleasePreconditions(t *testing.T) {
	scriptPath := filepath.Join(".github", "scripts", "test_ci.sh")
	if _, err := os.Stat(scriptPath); os.IsNotExist(err) {
		dir, _ := os.Getwd()
		for {
			cand := filepath.Join(dir, ".github", "scripts", "test_ci.sh")
			if _, err := os.Stat(cand); err == nil {
				scriptPath = cand
				break
			}
			parent := filepath.Dir(dir)
			if parent == dir {
				break
			}
			dir = parent
		}
	}
	cmd := exec.Command(scriptPath)
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("CI routing and release precondition test suite failed: %v\nOutput:\n%s", err, string(output))
	}
}
