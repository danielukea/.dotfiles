package ui

import "github.com/charmbracelet/lipgloss"

// Color palette
var (
	ColorPrimary = lipgloss.Color("#5B9BD5") // blue
	ColorOK      = lipgloss.Color("#6BCB77") // green
	ColorWarning = lipgloss.Color("#FFD93D") // yellow/amber
	ColorDanger  = lipgloss.Color("#FF6B6B") // red
	ColorMuted   = lipgloss.Color("#6C757D") // gray
	ColorBg      = lipgloss.Color("#1E1E2E") // dark background
	ColorFg      = lipgloss.Color("#CDD6F4") // light foreground
	ColorBorder  = lipgloss.Color("#45475A") // subtle border
)

// Layout styles
var (
	SidebarStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(ColorBorder).
			Padding(1, 1)

	SidebarTitle = lipgloss.NewStyle().
			Bold(true).
			Foreground(ColorPrimary).
			MarginBottom(1)

	SelectedItem = lipgloss.NewStyle().
			Bold(true).
			Foreground(ColorPrimary).
			PaddingLeft(1)

	NormalItem = lipgloss.NewStyle().
			Foreground(ColorFg).
			PaddingLeft(1)

	DetailPanel = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(ColorBorder).
			Padding(1, 2)

	SectionTitle = lipgloss.NewStyle().
			Bold(true).
			Foreground(ColorPrimary).
			MarginTop(1).
			MarginBottom(0)

	StatusOK = lipgloss.NewStyle().
			Bold(true).
			Foreground(ColorOK)

	StatusWaiting = lipgloss.NewStyle().
			Bold(true).
			Foreground(ColorWarning)

	StatusDead = lipgloss.NewStyle().
			Bold(true).
			Foreground(ColorDanger)

	StatusRunning = lipgloss.NewStyle().
			Bold(true).
			Foreground(ColorOK)

	FooterStyle = lipgloss.NewStyle().
			Foreground(ColorMuted).
			MarginTop(1)

	WaitingIndicator = lipgloss.NewStyle().
				Foreground(ColorWarning).
				Bold(true)

	MutedText = lipgloss.NewStyle().
			Foreground(ColorMuted)

	BranchStyle = lipgloss.NewStyle().
			Foreground(ColorFg)
)
