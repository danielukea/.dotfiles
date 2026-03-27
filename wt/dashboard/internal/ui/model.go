package ui

import (
	"fmt"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"github.com/lukedanielson/wt-dash/internal/agent"
	gitpkg "github.com/lukedanielson/wt-dash/internal/git"
	"github.com/lukedanielson/wt-dash/internal/process"
	"github.com/lukedanielson/wt-dash/internal/services"
	"github.com/lukedanielson/wt-dash/internal/state"
	"github.com/lukedanielson/wt-dash/internal/tmux"
)

// Focus tracks which panel has keyboard focus.
type Focus int

const (
	FocusSidebar Focus = iota
	FocusAgents
)

// AgentLive holds live-polled data for a single agent.
type AgentLive struct {
	Status    agent.Status
	Resources process.Resources
}

// WorktreeLive holds live-polled data for a single worktree.
type WorktreeLive struct {
	GitStatus  gitpkg.Status
	Commits    []gitpkg.Commit
	Services   *services.Status
	Agents     map[string]AgentLive
}

// Model is the main Bubbletea model for the dashboard.
type Model struct {
	reader    *state.Reader
	names     []string
	selected  int
	focus     Focus
	agentIdx  int
	width     int
	height    int
	live      map[string]*WorktreeLive
	tickCount int
	switchTo  string // set when user presses enter
}

// NewModel creates a new dashboard model.
func NewModel(reader *state.Reader) Model {
	names := reader.WorktreeNames()
	return Model{
		reader: reader,
		names:  names,
		live:   make(map[string]*WorktreeLive),
	}
}

// Messages
type tickMsg time.Time
type stateUpdatedMsg struct{}
type gitPolledMsg struct {
	name    string
	status  gitpkg.Status
	commits []gitpkg.Commit
}
type servicesPolledMsg struct {
	name     string
	services *services.Status
}

func tickCmd() tea.Cmd {
	return tea.Tick(2*time.Second, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}

// Init starts the tick and loads initial state.
func (m Model) Init() tea.Cmd {
	return tea.Batch(tickCmd(), m.loadState())
}

func (m Model) loadState() tea.Cmd {
	return func() tea.Msg {
		_ = m.reader.Load()
		return stateUpdatedMsg{}
	}
}

// Update handles messages.
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		return m.handleKey(msg)

	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		return m, nil

	case tickMsg:
		m.tickCount++
		// Reload state every tick
		_ = m.reader.Load()
		m.names = m.reader.WorktreeNames()
		if m.selected >= len(m.names) && len(m.names) > 0 {
			m.selected = len(m.names) - 1
		}

		// Poll agent status inline (fast — just kill -0 and ps)
		m.pollAgents()

		var cmds []tea.Cmd
		cmds = append(cmds, tickCmd())

		// Poll git every 5 ticks (10 seconds) — async
		if m.tickCount%5 == 0 {
			cmds = append(cmds, m.pollGitAsync()...)
		}

		// Poll services every 15 ticks (30 seconds) — async
		if m.tickCount%15 == 0 {
			cmds = append(cmds, m.pollServicesAsync()...)
		}

		return m, tea.Batch(cmds...)

	case stateUpdatedMsg:
		// Initial load — just update names, don't block on polling
		m.names = m.reader.WorktreeNames()
		m.pollAgents()
		// Kick off async git poll so data appears quickly
		return m, tea.Batch(m.pollGitAsync()...)

	case gitPolledMsg:
		if m.live[msg.name] == nil {
			m.live[msg.name] = &WorktreeLive{Agents: make(map[string]AgentLive)}
		}
		m.live[msg.name].GitStatus = msg.status
		m.live[msg.name].Commits = msg.commits
		return m, nil

	case servicesPolledMsg:
		if m.live[msg.name] == nil {
			m.live[msg.name] = &WorktreeLive{Agents: make(map[string]AgentLive)}
		}
		m.live[msg.name].Services = msg.services
		return m, nil
	}

	return m, nil
}

func (m Model) handleKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "q", "ctrl+c":
		return m, tea.Quit

	case "j", "down":
		if m.focus == FocusSidebar {
			if m.selected < len(m.names)-1 {
				m.selected++
				m.agentIdx = 0
			}
		} else if m.focus == FocusAgents {
			wt := m.selectedWorktree()
			if wt != nil {
				agentNames := sortedAgentNames(wt.Agents)
				if m.agentIdx < len(agentNames)-1 {
					m.agentIdx++
				}
			}
		}

	case "k", "up":
		if m.focus == FocusSidebar {
			if m.selected > 0 {
				m.selected--
				m.agentIdx = 0
			}
		} else if m.focus == FocusAgents {
			if m.agentIdx > 0 {
				m.agentIdx--
			}
		}

	case "tab":
		if m.focus == FocusSidebar {
			m.focus = FocusAgents
			m.agentIdx = 0
		} else {
			m.focus = FocusSidebar
		}

	case "enter":
		wt := m.selectedWorktree()
		if wt != nil && tmux.HasSession(wt.Session) {
			m.switchTo = wt.Session
			return m, tea.Quit
		}
	}

	return m, nil
}

func (m *Model) selectedWorktree() *state.Worktree {
	if len(m.names) == 0 || m.selected >= len(m.names) {
		return nil
	}
	s := m.reader.Get()
	wt, ok := s.Worktrees[m.names[m.selected]]
	if !ok {
		return nil
	}
	return &wt
}

func (m *Model) pollAgents() {
	s := m.reader.Get()
	for name, wt := range s.Worktrees {
		if m.live[name] == nil {
			m.live[name] = &WorktreeLive{Agents: make(map[string]AgentLive)}
		}
		for aName, a := range wt.Agents {
			status := agent.DetectStatus(a.PID, a.TmuxWindow)
			res := process.GetResources(a.PID)
			m.live[name].Agents[aName] = AgentLive{
				Status:    status,
				Resources: res,
			}
		}
	}
}

func (m *Model) pollGitAsync() []tea.Cmd {
	s := m.reader.Get()
	var cmds []tea.Cmd
	for name, wt := range s.Worktrees {
		n, p := name, wt.Path
		cmds = append(cmds, func() tea.Msg {
			return gitPolledMsg{
				name:    n,
				status:  gitpkg.GetStatus(p),
				commits: gitpkg.RecentCommits(p, 5),
			}
		})
	}
	return cmds
}

func (m *Model) pollServicesAsync() []tea.Cmd {
	s := m.reader.Get()
	var cmds []tea.Cmd
	for name, wt := range s.Worktrees {
		n, p := name, wt.Path
		cmds = append(cmds, func() tea.Msg {
			return servicesPolledMsg{
				name:     n,
				services: services.GetStatus(p),
			}
		})
	}
	return cmds
}

// SwitchTo returns the session to switch to after quitting, if any.
func (m Model) SwitchTo() string {
	return m.switchTo
}

// View renders the dashboard.
func (m Model) View() string {
	if m.width == 0 {
		return "Loading..."
	}

	sidebarWidth := 28
	detailWidth := m.width - sidebarWidth - 4 // borders and padding
	if detailWidth < 30 {
		detailWidth = 30
	}
	contentHeight := m.height - 4 // footer + borders

	// Sidebar
	sidebar := m.renderSidebar(sidebarWidth-4, contentHeight-4)
	sidebarBox := SidebarStyle.
		Width(sidebarWidth).
		Height(contentHeight).
		Render(sidebar)

	// Detail panel
	detail := m.renderDetail(detailWidth-6, contentHeight-4)
	detailBox := DetailPanel.
		Width(detailWidth).
		Height(contentHeight).
		Render(detail)

	main := lipgloss.JoinHorizontal(lipgloss.Top, sidebarBox, detailBox)

	footer := FooterStyle.Render(" [j/k] navigate  [enter] attach  [tab] focus  [q] quit")

	return lipgloss.JoinVertical(lipgloss.Left, main, footer)
}

func (m Model) renderSidebar(width, height int) string {
	var b strings.Builder
	b.WriteString(SidebarTitle.Render("Workspaces"))
	b.WriteString("\n")

	s := m.reader.Get()

	for i, name := range m.names {
		wt := s.Worktrees[name]
		label := name

		// Agent count
		if len(wt.Agents) > 0 {
			label += MutedText.Render(fmt.Sprintf(" (%d)", len(wt.Agents)))
		}

		// Waiting indicator
		hasWaiting := false
		if live, ok := m.live[name]; ok {
			for _, al := range live.Agents {
				if al.Status == agent.StatusWaiting {
					hasWaiting = true
					break
				}
			}
		}
		if hasWaiting {
			label += " " + WaitingIndicator.Render("[!]")
		}

		if i == m.selected {
			b.WriteString(SelectedItem.Render("> " + label))
		} else {
			b.WriteString(NormalItem.Render("  " + label))
		}
		if i < len(m.names)-1 {
			b.WriteString("\n")
		}
	}

	if len(m.names) == 0 {
		b.WriteString(MutedText.Render("  No worktrees"))
	}

	return b.String()
}

func (m Model) renderDetail(width, height int) string {
	wt := m.selectedWorktree()
	if wt == nil {
		return MutedText.Render("No worktree selected")
	}

	name := m.names[m.selected]
	var b strings.Builder

	// Title
	b.WriteString(SectionTitle.Render("Details: " + name))
	b.WriteString("\n\n")

	// Branch info
	branchInfo := "Branch: " + wt.Branch
	if live, ok := m.live[name]; ok {
		gs := live.GitStatus
		parts := []string{}
		if gs.Ahead > 0 {
			parts = append(parts, fmt.Sprintf("%d ahead", gs.Ahead))
		}
		if gs.Behind > 0 {
			parts = append(parts, fmt.Sprintf("%d behind", gs.Behind))
		}
		if gs.Dirty {
			parts = append(parts, "dirty")
		} else {
			parts = append(parts, "clean")
		}
		if len(parts) > 0 {
			branchInfo += " (" + strings.Join(parts, ", ") + ")"
		}
	}
	b.WriteString(BranchStyle.Render(branchInfo))
	b.WriteString("\n")

	// Services
	if live, ok := m.live[name]; ok && live.Services != nil {
		b.WriteString("\n")
		b.WriteString(SectionTitle.Render("Services"))
		b.WriteString("\n")
		for svcName, svc := range live.Services.Services {
			status := StatusOK.Render("UP")
			if !svc.Running {
				status = StatusDead.Render("DOWN")
			}
			b.WriteString(fmt.Sprintf("  %s  %-10s  %s\n", status, svcName, MutedText.Render(svc.HostPort)))
		}
	}

	// Agents
	b.WriteString("\n")
	b.WriteString(SectionTitle.Render("Agents"))
	b.WriteString("\n")

	if len(wt.Agents) == 0 {
		b.WriteString(MutedText.Render("  No agents running"))
		b.WriteString("\n")
	} else {
		agentNames := sortedAgentNames(wt.Agents)
		for i, aName := range agentNames {
			a := wt.Agents[aName]
			uptime := formatDuration(time.Since(a.StartedAt))

			// Status
			statusStr := MutedText.Render("???")
			if live, ok := m.live[name]; ok {
				if al, ok2 := live.Agents[aName]; ok2 {
					switch al.Status {
					case agent.StatusWaiting:
						statusStr = StatusWaiting.Render("WAITING")
					case agent.StatusRunning:
						statusStr = StatusRunning.Render("RUNNING")
					case agent.StatusDead:
						statusStr = StatusDead.Render("DEAD   ")
					}
				}
			}

			// Memory
			memStr := ""
			if live, ok := m.live[name]; ok {
				if al, ok2 := live.Agents[aName]; ok2 && al.Resources.Alive {
					memStr = MutedText.Render(fmt.Sprintf("  %dMB", int(al.Resources.MemoryMB)))
				}
			}

			cursor := "  "
			if m.focus == FocusAgents && i == m.agentIdx {
				cursor = SelectedItem.Render("> ")
			}

			b.WriteString(fmt.Sprintf("%s%s  %-12s %-14s %s%s\n",
				cursor, statusStr, aName, a.Type, uptime, memStr))
		}
	}

	// Resource totals
	if live, ok := m.live[name]; ok && len(live.Agents) > 0 {
		var totalMem float64
		var totalCPU float64
		for _, al := range live.Agents {
			if al.Resources.Alive {
				totalMem += al.Resources.MemoryMB
				totalCPU += al.Resources.CPUPercent
			}
		}
		b.WriteString("\n")
		b.WriteString(SectionTitle.Render("Resources"))
		b.WriteString("\n")
		b.WriteString(MutedText.Render(fmt.Sprintf("  Total: %dMB RAM, %.0f%% CPU", int(totalMem), totalCPU)))
		b.WriteString("\n")
	}

	// Recent commits
	if live, ok := m.live[name]; ok && len(live.Commits) > 0 {
		b.WriteString("\n")
		b.WriteString(SectionTitle.Render("Recent Commits"))
		b.WriteString("\n")
		for _, c := range live.Commits {
			age := formatDuration(c.Age)
			msg := c.Message
			if len(msg) > width-15 {
				msg = msg[:width-18] + "..."
			}
			b.WriteString(fmt.Sprintf("  %s  %s\n",
				MutedText.Render(fmt.Sprintf("%-8s", age)),
				msg))
		}
	}

	return b.String()
}

func sortedAgentNames(agents map[string]state.Agent) []string {
	names := make([]string, 0, len(agents))
	for n := range agents {
		names = append(names, n)
	}
	// Simple sort
	for i := 0; i < len(names); i++ {
		for j := i + 1; j < len(names); j++ {
			if names[i] > names[j] {
				names[i], names[j] = names[j], names[i]
			}
		}
	}
	return names
}

func formatDuration(d time.Duration) string {
	if d < time.Minute {
		return fmt.Sprintf("%ds", int(d.Seconds()))
	}
	if d < time.Hour {
		return fmt.Sprintf("%dm", int(d.Minutes()))
	}
	if d < 24*time.Hour {
		return fmt.Sprintf("%dh", int(d.Hours()))
	}
	return fmt.Sprintf("%dd", int(d.Hours()/24))
}
