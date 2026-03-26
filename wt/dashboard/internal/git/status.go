package git

import (
	"fmt"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

// Status holds git branch status information.
type Status struct {
	Dirty  bool
	Ahead  int
	Behind int
}

// Commit holds information about a single git commit.
type Commit struct {
	Hash    string
	Message string
	Age     time.Duration
}

// GetStatus returns the git status for a worktree path.
func GetStatus(path string) Status {
	var s Status

	// Check dirty status
	cmd := exec.Command("git", "-C", path, "status", "--porcelain")
	out, err := cmd.Output()
	if err == nil && len(strings.TrimSpace(string(out))) > 0 {
		s.Dirty = true
	}

	// Check ahead/behind
	cmd = exec.Command("git", "-C", path, "rev-list", "--left-right", "--count", "HEAD...@{upstream}")
	out, err = cmd.Output()
	if err == nil {
		fields := strings.Fields(strings.TrimSpace(string(out)))
		if len(fields) == 2 {
			s.Ahead, _ = strconv.Atoi(fields[0])
			s.Behind, _ = strconv.Atoi(fields[1])
		}
	}

	return s
}

// RecentCommits returns the last n commits for a worktree path.
func RecentCommits(path string, n int) []Commit {
	cmd := exec.Command("git", "-C", path, "log",
		fmt.Sprintf("-%d", n),
		"--format=%H\t%s\t%ct",
	)
	out, err := cmd.Output()
	if err != nil {
		return nil
	}

	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	commits := make([]Commit, 0, len(lines))
	now := time.Now()

	for _, line := range lines {
		if line == "" {
			continue
		}
		parts := strings.SplitN(line, "\t", 3)
		if len(parts) < 3 {
			continue
		}
		ts, err := strconv.ParseInt(parts[2], 10, 64)
		if err != nil {
			continue
		}
		commits = append(commits, Commit{
			Hash:    parts[0][:7],
			Message: parts[1],
			Age:     now.Sub(time.Unix(ts, 0)),
		})
	}

	return commits
}
