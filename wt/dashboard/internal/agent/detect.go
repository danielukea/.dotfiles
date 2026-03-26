package agent

import (
	"strings"

	"github.com/lukedanielson/wt-dash/internal/process"
	"github.com/lukedanielson/wt-dash/internal/tmux"
)

// Status represents the detected state of an agent.
type Status int

const (
	StatusRunning Status = iota
	StatusWaiting
	StatusDead
)

// String returns a human-readable label for the status.
func (s Status) String() string {
	switch s {
	case StatusRunning:
		return "RUNNING"
	case StatusWaiting:
		return "WAITING"
	case StatusDead:
		return "DEAD"
	default:
		return "UNKNOWN"
	}
}

// promptPatterns are strings that indicate Claude is waiting for input.
var promptPatterns = []string{
	">",
	"❯",
	"What would you like",
	"claude>",
	"Claude Code",
}

// DetectStatus combines tmux pane content and CPU usage to determine agent state.
func DetectStatus(pid int, tmuxTarget string) Status {
	if !process.IsAlive(pid) {
		return StatusDead
	}

	res := process.GetResources(pid)
	if !res.Alive {
		return StatusDead
	}

	hasPrompt := false
	lines, err := tmux.CapturePaneLines(tmuxTarget, 5)
	if err == nil {
		for _, line := range lines {
			trimmed := strings.TrimSpace(line)
			if trimmed == "" {
				continue
			}
			for _, pattern := range promptPatterns {
				if strings.Contains(trimmed, pattern) {
					hasPrompt = true
					break
				}
			}
			if hasPrompt {
				break
			}
		}
	}

	if hasPrompt && res.CPUPercent < 2.0 {
		return StatusWaiting
	}

	return StatusRunning
}
