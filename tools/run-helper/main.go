package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const defaultMaxOutput = 1 << 20

type limitedBuffer struct {
	data      []byte
	max       int
	truncated bool
}

func (b *limitedBuffer) Write(p []byte) (int, error) {
	n := len(p)
	remaining := b.max - len(b.data)
	if remaining > 0 {
		take := len(p)
		if take > remaining {
			take = remaining
		}
		b.data = append(b.data, p[:take]...)
	}
	if len(p) > remaining {
		b.truncated = true
	}
	return n, nil
}

func (b *limitedBuffer) String() string { return string(b.data) }

type result struct {
	OK              bool   `json:"ok"`
	ExitCode        int    `json:"exit_code"`
	TimedOut        bool   `json:"timed_out"`
	DurationMS      int64  `json:"duration_ms"`
	Stdout          string `json:"stdout"`
	Stderr          string `json:"stderr"`
	StdoutTruncated bool   `json:"stdout_truncated"`
	StderrTruncated bool   `json:"stderr_truncated"`
	Error           string `json:"error,omitempty"`
}

func main() {
	r := run(os.Args[1:])
	enc := json.NewEncoder(os.Stdout)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(r); err != nil {
		os.Exit(2)
	}
	if !r.OK && !r.TimedOut && r.ExitCode == -1 {
		os.Exit(1)
	}
}

func run(args []string) result {
	timeoutMS := 10000
	maxOutput := defaultMaxOutput
	sep := -1
	for i, arg := range args {
		if arg == "--" {
			sep = i
			break
		}
		switch arg {
		case "--timeout-ms":
			if i+1 >= len(args) {
				return configError("missing --timeout-ms value")
			}
			value, err := strconv.Atoi(args[i+1])
			if err != nil {
				return configError("invalid --timeout-ms")
			}
			timeoutMS = value
		case "--max-output-bytes":
			if i+1 >= len(args) {
				return configError("missing --max-output-bytes value")
			}
			value, err := strconv.Atoi(args[i+1])
			if err != nil {
				return configError("invalid --max-output-bytes")
			}
			maxOutput = value
		}
	}
	if sep < 0 || sep+1 >= len(args) {
		return configError("expected -- followed by executable and arguments")
	}
	if timeoutMS < 100 || timeoutMS > 120000 {
		return configError("timeout must be between 100 and 120000 ms")
	}
	if maxOutput < 4096 || maxOutput > 8<<20 {
		return configError("max output must be between 4096 and 8388608 bytes")
	}

	executable := strings.TrimSpace(args[sep+1])
	if executable == "" {
		return configError("empty executable")
	}
	childArgs := args[sep+2:]
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(timeoutMS)*time.Millisecond)
	defer cancel()

	var stdout limitedBuffer
	stdout.max = maxOutput
	var stderr limitedBuffer
	stderr.max = maxOutput
	cmd := exec.CommandContext(ctx, executable, childArgs...)
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	cmd.Stdin = nil
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: 0x08000000}

	startedAt := time.Now()
	err := cmd.Run()
	duration := time.Since(startedAt).Milliseconds()
	timedOut := errors.Is(ctx.Err(), context.DeadlineExceeded)
	exitCode := 0
	if err != nil {
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			exitCode = exitErr.ExitCode()
		} else {
			exitCode = -1
		}
	}
	if timedOut {
		exitCode = -1
	}
	r := result{
		OK:              err == nil && !timedOut,
		ExitCode:        exitCode,
		TimedOut:        timedOut,
		DurationMS:      duration,
		Stdout:          stdout.String(),
		Stderr:          stderr.String(),
		StdoutTruncated: stdout.truncated,
		StderrTruncated: stderr.truncated,
	}
	if err != nil && !timedOut && exitCode == -1 {
		r.Error = fmt.Sprintf("start/run failed: %v", err)
	}
	if timedOut {
		r.Error = "process timed out"
	}
	return r
}

func configError(message string) result {
	return result{OK: false, ExitCode: -1, Error: message}
}
