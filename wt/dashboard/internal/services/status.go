package services

import (
	"encoding/json"
	"os/exec"
	"path/filepath"
)

// Service represents a single running service.
type Service struct {
	URL      string `json:"url"`
	Running  bool   `json:"running"`
	HostPort string `json:"host_port"`
}

// Status holds the result of bin/wealthbox status.
type Status struct {
	Mode     string             `json:"mode"`
	Project  string             `json:"project"`
	Services map[string]Service `json:"services"`
}

// GetStatus runs bin/wealthbox status in the worktree and parses its JSON output.
func GetStatus(worktreePath string) *Status {
	bin := filepath.Join(worktreePath, "bin", "wealthbox")
	cmd := exec.Command(bin, "status")
	cmd.Dir = worktreePath
	out, err := cmd.Output()
	if err != nil {
		return nil
	}

	var s Status
	if err := json.Unmarshal(out, &s); err != nil {
		return nil
	}
	return &s
}
