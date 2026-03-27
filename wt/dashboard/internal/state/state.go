package state

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sort"
	"sync"
	"time"
)

// Agent represents a running Claude agent in a worktree.
type Agent struct {
	PID        int       `json:"pid"`
	Type       string    `json:"type"`
	TmuxWindow string    `json:"tmux_window"`
	StartedAt  time.Time `json:"started_at"`
}

// Worktree represents a single git worktree managed by wt.
type Worktree struct {
	Repo       string           `json:"repo"`
	Path       string           `json:"path"`
	Branch     string           `json:"branch"`
	BaseBranch string           `json:"base_branch"`
	Session    string           `json:"session"`
	Owner      string           `json:"owner,omitempty"`
	CreatedAt  time.Time        `json:"created_at"`
	Agents     map[string]Agent `json:"agents"`
}

// State is the top-level structure of the wt state file.
type State struct {
	Worktrees map[string]Worktree `json:"worktrees"`
}

// Reader provides thread-safe access to the wt state file.
type Reader struct {
	path  string
	mu    sync.RWMutex
	state State
}

// DefaultPath returns the path to the state file, respecting WT_STATE_FILE env.
func DefaultPath() string {
	if p := os.Getenv("WT_STATE_FILE"); p != "" {
		return p
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".local", "share", "wt", "state.json")
}

// NewReader creates a new state reader for the given path.
func NewReader(path string) *Reader {
	return &Reader{path: path}
}

// Load reads and parses the state file from disk.
func (r *Reader) Load() error {
	data, err := os.ReadFile(r.path)
	if err != nil {
		if os.IsNotExist(err) {
			r.mu.Lock()
			r.state = State{Worktrees: make(map[string]Worktree)}
			r.mu.Unlock()
			return nil
		}
		return err
	}

	var s State
	if err := json.Unmarshal(data, &s); err != nil {
		return err
	}
	if s.Worktrees == nil {
		s.Worktrees = make(map[string]Worktree)
	}

	r.mu.Lock()
	r.state = s
	r.mu.Unlock()
	return nil
}

// Get returns a copy of the current state.
func (r *Reader) Get() State {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.state
}

// WorktreeNames returns a sorted list of worktree names.
func (r *Reader) WorktreeNames() []string {
	r.mu.RLock()
	defer r.mu.RUnlock()

	names := make([]string, 0, len(r.state.Worktrees))
	for name := range r.state.Worktrees {
		names = append(names, name)
	}
	sort.Strings(names)
	return names
}
