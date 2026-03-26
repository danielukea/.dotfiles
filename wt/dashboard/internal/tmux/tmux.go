package tmux

import (
	"os/exec"
	"strings"
)

// CapturePaneLines captures the last N lines from a tmux pane.
func CapturePaneLines(target string, lines int) ([]string, error) {
	cmd := exec.Command("tmux", "capture-pane", "-p", "-t", target)
	out, err := cmd.Output()
	if err != nil {
		return nil, err
	}

	all := strings.Split(strings.TrimRight(string(out), "\n"), "\n")
	if len(all) <= lines {
		return all, nil
	}
	return all[len(all)-lines:], nil
}

// HasSession checks if a tmux session exists.
func HasSession(name string) bool {
	cmd := exec.Command("tmux", "has-session", "-t", name)
	return cmd.Run() == nil
}

// SwitchClient switches the current tmux client to the given session.
func SwitchClient(session string) error {
	cmd := exec.Command("tmux", "switch-client", "-t", session)
	return cmd.Run()
}
