package main

import (
	"fmt"
	"os"
	"os/exec"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/lukedanielson/wt-dash/internal/state"
	"github.com/lukedanielson/wt-dash/internal/ui"
)

func main() {
	reader := state.NewReader(state.DefaultPath())
	if err := reader.Load(); err != nil {
		fmt.Fprintf(os.Stderr, "wt-dash: failed to load state: %v\n", err)
		os.Exit(1)
	}

	m := ui.NewModel(reader)
	p := tea.NewProgram(m, tea.WithAltScreen())

	finalModel, err := p.Run()
	if err != nil {
		fmt.Fprintf(os.Stderr, "wt-dash: %v\n", err)
		os.Exit(1)
	}

	// If user pressed enter to attach, switch tmux client
	if fm, ok := finalModel.(ui.Model); ok {
		if session := fm.SwitchTo(); session != "" {
			cmd := exec.Command("tmux", "switch-client", "-t", session)
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			_ = cmd.Run()
		}
	}
}
