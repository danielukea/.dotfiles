package process

import (
	"fmt"
	"os/exec"
	"strconv"
	"strings"
	"syscall"
)

// Resources holds process resource usage.
type Resources struct {
	MemoryMB   float64
	CPUPercent float64
	Alive      bool
}

// GetResources returns resource usage for a given PID.
func GetResources(pid int) Resources {
	if !IsAlive(pid) {
		return Resources{Alive: false}
	}

	cmd := exec.Command("ps", "-o", "rss=,%cpu=", "-p", fmt.Sprintf("%d", pid))
	out, err := cmd.Output()
	if err != nil {
		return Resources{Alive: false}
	}

	fields := strings.Fields(strings.TrimSpace(string(out)))
	if len(fields) < 2 {
		return Resources{Alive: true}
	}

	rssKB, _ := strconv.ParseFloat(fields[0], 64)
	cpu, _ := strconv.ParseFloat(fields[1], 64)

	return Resources{
		MemoryMB:   rssKB / 1024.0,
		CPUPercent: cpu,
		Alive:      true,
	}
}

// IsAlive checks if a process with the given PID is running.
func IsAlive(pid int) bool {
	return syscall.Kill(pid, 0) == nil
}
