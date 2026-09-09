//go:build windows

package main

import (
	"archive/zip"
	"bytes"
	_ "embed"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"time"
	"unicode/utf16"
	"unsafe"
)

//go:embed payload.zip
var payloadZip []byte

var version = "dev"
var buildCommit = "unknown"

const (
	pluginRelative = "addons/godot_mcp_chatgpt"
	pluginConfig   = "addons/godot_mcp_chatgpt/plugin.cfg"
	pluginResPath  = "res://addons/godot_mcp_chatgpt/plugin.cfg"
)

type installResult struct {
	OK          bool   `json:"ok"`
	Canceled    bool   `json:"canceled,omitempty"`
	Version     string `json:"version"`
	BuildCommit string `json:"build_commit"`
	Project     string `json:"project,omitempty"`
	Target      string `json:"target,omitempty"`
	Enabled     bool   `json:"enabled"`
	Upgraded    bool   `json:"upgraded"`
	Message     string `json:"message"`
}

type openFileNameW struct {
	LStructSize       uint32
	HwndOwner         uintptr
	HInstance         uintptr
	LpstrFilter       *uint16
	LpstrCustomFilter *uint16
	NMaxCustFilter    uint32
	NFilterIndex      uint32
	LpstrFile         *uint16
	NMaxFile          uint32
	LpstrFileTitle    *uint16
	NMaxFileTitle     uint32
	LpstrInitialDir   *uint16
	LpstrTitle        *uint16
	Flags             uint32
	NFileOffset       uint16
	NFileExtension    uint16
	LpstrDefExt       *uint16
	LCustData         uintptr
	LpfnHook          uintptr
	LpTemplateName    *uint16
	PvReserved        uintptr
	DwReserved        uint32
	FlagsEx           uint32
}

var (
	comdlg32             = syscall.NewLazyDLL("comdlg32.dll")
	user32               = syscall.NewLazyDLL("user32.dll")
	procGetOpenFileNameW = comdlg32.NewProc("GetOpenFileNameW")
	procCommDlgExtError  = comdlg32.NewProc("CommDlgExtendedError")
	procMessageBoxW      = user32.NewProc("MessageBoxW")
)

func main() {
	projectArg := flag.String("project", "", "Godot project directory or project.godot path")
	silent := flag.Bool("silent", false, "Do not show GUI result dialogs")
	noEnable := flag.Bool("no-enable", false, "Install files without enabling the editor plugin")
	resultPath := flag.String("result", "", "Write machine-readable JSON result to this path")
	flag.Parse()

	result, code := runInstaller(*projectArg, !*noEnable)
	if *resultPath != "" {
		_ = writeJSONResult(*resultPath, result)
	}
	if !*silent && !result.Canceled {
		flags := uintptr(0x40) // MB_ICONINFORMATION
		if !result.OK {
			flags = 0x10 // MB_ICONERROR
		}
		messageBox(result.Message, "Godot MCP ChatGPT Installer", flags)
	}
	os.Exit(code)
}

func runInstaller(projectArg string, enable bool) (installResult, int) {
	result := installResult{Version: version, BuildCommit: buildCommit}

	projectPath := strings.TrimSpace(projectArg)
	if projectPath == "" {
		selected, canceled, err := chooseProjectFile()
		if err != nil {
			result.Message = "Unable to open the project picker: " + err.Error()
			return result, 10
		}
		if canceled {
			result.Canceled = true
			result.Message = "Installation canceled."
			return result, 0
		}
		projectPath = selected
	}

	projectDir, projectFile, err := normalizeProjectPath(projectPath)
	if err != nil {
		result.Message = err.Error()
		return result, 11
	}
	result.Project = projectDir
	result.Target = filepath.Join(projectDir, filepath.FromSlash(pluginRelative))

	upgraded, err := installAddon(projectDir)
	if err != nil {
		result.Message = "Installation failed: " + err.Error() + "\n\nIf Godot is currently using this project, close the editor and try again."
		return result, 12
	}
	result.Upgraded = upgraded

	if enable {
		if _, err := ensurePluginEnabled(projectFile); err != nil {
			result.Message = "The addon files were installed, but project.godot could not be updated automatically: " + err.Error() + "\n\nEnable Godot MCP ChatGPT manually from Project > Project Settings > Plugins."
			return result, 13
		}
		result.Enabled = true
	}

	action := "installed"
	if upgraded {
		action = "upgraded"
	}
	result.OK = true
	result.Message = fmt.Sprintf("Godot MCP ChatGPT %s was %s successfully.\n\nProject:\n%s\n\nInstalled to:\n%s", version, action, projectDir, result.Target)
	if enable {
		result.Message += "\n\nThe editor plugin is enabled. If this project is already open in Godot, restart/reopen the project so the new plugin files are loaded cleanly."
	} else {
		result.Message += "\n\nThe addon was not enabled automatically. Enable it from Project > Project Settings > Plugins."
	}
	return result, 0
}

func chooseProjectFile() (string, bool, error) {
	fileBuf := make([]uint16, 32768)
	filter := utf16.Encode([]rune("Godot project (project.godot)\x00project.godot\x00\x00"))
	title, _ := syscall.UTF16PtrFromString("Select the target Godot project's project.godot")

	ofn := openFileNameW{
		LpstrFilter:  &filter[0],
		NFilterIndex: 1,
		LpstrFile:    &fileBuf[0],
		NMaxFile:     uint32(len(fileBuf)),
		LpstrTitle:   title,
		Flags:        0x00001000 | 0x00000800 | 0x00080000 | 0x00000004, // FILEMUSTEXIST | PATHMUSTEXIST | EXPLORER | HIDEREADONLY
	}
	ofn.LStructSize = uint32(unsafe.Sizeof(ofn))

	ret, _, _ := procGetOpenFileNameW.Call(uintptr(unsafe.Pointer(&ofn)))
	if ret == 0 {
		code, _, _ := procCommDlgExtError.Call()
		if code == 0 {
			return "", true, nil
		}
		return "", false, fmt.Errorf("Windows file dialog error 0x%X", code)
	}
	return syscall.UTF16ToString(fileBuf), false, nil
}

func messageBox(message, title string, flags uintptr) {
	msg, _ := syscall.UTF16PtrFromString(message)
	ttl, _ := syscall.UTF16PtrFromString(title)
	procMessageBoxW.Call(0, uintptr(unsafe.Pointer(msg)), uintptr(unsafe.Pointer(ttl)), flags)
}

func normalizeProjectPath(input string) (string, string, error) {
	abs, err := filepath.Abs(input)
	if err != nil {
		return "", "", fmt.Errorf("invalid project path: %w", err)
	}
	info, err := os.Stat(abs)
	if err != nil {
		return "", "", fmt.Errorf("project path does not exist: %s", abs)
	}

	projectDir := abs
	projectFile := filepath.Join(projectDir, "project.godot")
	if !info.IsDir() {
		if !strings.EqualFold(filepath.Base(abs), "project.godot") {
			return "", "", errors.New("select a Godot project directory or its project.godot file")
		}
		projectFile = abs
		projectDir = filepath.Dir(abs)
	}
	if info, err := os.Stat(projectFile); err != nil || info.IsDir() {
		return "", "", fmt.Errorf("not a Godot project: project.godot was not found in %s", projectDir)
	}
	return filepath.Clean(projectDir), filepath.Clean(projectFile), nil
}

func installAddon(projectDir string) (bool, error) {
	if len(payloadZip) == 0 {
		return false, errors.New("installer payload is empty")
	}

	stageDir, err := os.MkdirTemp(projectDir, ".godot-mcp-chatgpt-install-*")
	if err != nil {
		return false, fmt.Errorf("create staging directory: %w", err)
	}
	defer os.RemoveAll(stageDir)

	if err := extractPayload(stageDir); err != nil {
		return false, err
	}
	stagedAddon := filepath.Join(stageDir, filepath.FromSlash(pluginRelative))
	stagedConfig := filepath.Join(stageDir, filepath.FromSlash(pluginConfig))
	if err := validatePluginConfig(stagedConfig); err != nil {
		return false, err
	}

	addonsDir := filepath.Join(projectDir, "addons")
	if err := os.MkdirAll(addonsDir, 0o755); err != nil {
		return false, fmt.Errorf("create addons directory: %w", err)
	}
	target := filepath.Join(projectDir, filepath.FromSlash(pluginRelative))
	_, statErr := os.Stat(target)
	upgraded := statErr == nil
	if statErr != nil && !os.IsNotExist(statErr) {
		return false, fmt.Errorf("inspect existing addon: %w", statErr)
	}

	backup := ""
	if upgraded {
		backup = filepath.Join(addonsDir, fmt.Sprintf("godot_mcp_chatgpt.backup-%d-%d", time.Now().UnixNano(), os.Getpid()))
		if err := os.Rename(target, backup); err != nil {
			return false, fmt.Errorf("replace existing addon (close Godot if it is open): %w", err)
		}
	}

	if err := os.Rename(stagedAddon, target); err != nil {
		if backup != "" {
			_ = os.Rename(backup, target)
		}
		return false, fmt.Errorf("activate installed addon: %w", err)
	}
	if backup != "" {
		if err := os.RemoveAll(backup); err != nil {
			return upgraded, fmt.Errorf("new addon installed, but old backup could not be removed: %w", err)
		}
	}
	return upgraded, nil
}

func extractPayload(stageDir string) error {
	zr, err := zip.NewReader(bytes.NewReader(payloadZip), int64(len(payloadZip)))
	if err != nil {
		return fmt.Errorf("read embedded addon payload: %w", err)
	}
	stageAbs, err := filepath.Abs(stageDir)
	if err != nil {
		return err
	}
	for _, entry := range zr.File {
		clean := filepath.Clean(filepath.FromSlash(entry.Name))
		if filepath.IsAbs(clean) || clean == ".." || strings.HasPrefix(clean, ".."+string(filepath.Separator)) {
			return fmt.Errorf("unsafe payload path: %s", entry.Name)
		}
		dest := filepath.Join(stageAbs, clean)
		rel, err := filepath.Rel(stageAbs, dest)
		if err != nil || rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
			return fmt.Errorf("payload escaped staging directory: %s", entry.Name)
		}
		if entry.FileInfo().IsDir() {
			if err := os.MkdirAll(dest, 0o755); err != nil {
				return err
			}
			continue
		}
		if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
			return err
		}
		rc, err := entry.Open()
		if err != nil {
			return err
		}
		mode := entry.Mode().Perm()
		if mode == 0 {
			mode = 0o644
		}
		out, err := os.OpenFile(dest, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, mode)
		if err != nil {
			rc.Close()
			return err
		}
		_, copyErr := io.Copy(out, rc)
		closeErr := out.Close()
		rc.Close()
		if copyErr != nil {
			return copyErr
		}
		if closeErr != nil {
			return closeErr
		}
	}
	return nil
}

func validatePluginConfig(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("embedded addon is incomplete: %w", err)
	}
	text := string(data)
	if !strings.Contains(text, "name=\"Godot MCP ChatGPT\"") {
		return errors.New("embedded addon plugin.cfg has an unexpected plugin name")
	}
	if version != "dev" && !strings.Contains(text, "version=\""+version+"\"") {
		return fmt.Errorf("embedded addon version does not match installer version %s", version)
	}
	return nil
}

func ensurePluginEnabled(projectFile string) (bool, error) {
	original, err := os.ReadFile(projectFile)
	if err != nil {
		return false, err
	}
	bom := bytes.HasPrefix(original, []byte{0xEF, 0xBB, 0xBF})
	body := original
	if bom {
		body = body[3:]
	}
	newline := "\n"
	if bytes.Contains(body, []byte("\r\n")) {
		newline = "\r\n"
	}
	normalized := strings.ReplaceAll(string(body), "\r\n", "\n")
	lines := strings.Split(normalized, "\n")

	sectionStart := -1
	sectionEnd := len(lines)
	for i, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "[editor_plugins]" {
			sectionStart = i
			continue
		}
		if sectionStart >= 0 && i > sectionStart && strings.HasPrefix(trimmed, "[") && strings.HasSuffix(trimmed, "]") {
			sectionEnd = i
			break
		}
	}

	changed := false
	if sectionStart < 0 {
		for len(lines) > 0 && lines[len(lines)-1] == "" {
			lines = lines[:len(lines)-1]
		}
		lines = append(lines, "", "[editor_plugins]", "", "enabled=PackedStringArray(\""+pluginResPath+"\")", "")
		changed = true
	} else {
		enabledLine := -1
		for i := sectionStart + 1; i < sectionEnd; i++ {
			if strings.HasPrefix(strings.TrimSpace(lines[i]), "enabled=") {
				enabledLine = i
				break
			}
		}
		if enabledLine < 0 {
			insertAt := sectionStart + 1
			newLine := "enabled=PackedStringArray(\"" + pluginResPath + "\")"
			lines = append(lines[:insertAt], append([]string{newLine}, lines[insertAt:]...)...)
			changed = true
		} else if !strings.Contains(lines[enabledLine], "\""+pluginResPath+"\"") {
			trimmed := strings.TrimSpace(lines[enabledLine])
			prefix := "enabled=PackedStringArray("
			if !strings.HasPrefix(trimmed, prefix) || !strings.HasSuffix(trimmed, ")") {
				return false, errors.New("unsupported [editor_plugins] enabled format in project.godot")
			}
			inside := strings.TrimSpace(strings.TrimSuffix(strings.TrimPrefix(trimmed, prefix), ")"))
			if inside == "" {
				lines[enabledLine] = prefix + "\"" + pluginResPath + "\")"
			} else {
				lines[enabledLine] = prefix + inside + ", \"" + pluginResPath + "\")"
			}
			changed = true
		}
	}

	if !changed {
		return false, nil
	}
	updated := []byte(strings.Join(lines, newline))
	if bom {
		updated = append([]byte{0xEF, 0xBB, 0xBF}, updated...)
	}
	if err := replaceFileSafely(projectFile, updated); err != nil {
		return false, err
	}
	check, err := os.ReadFile(projectFile)
	if err != nil {
		return false, err
	}
	if !bytes.Contains(check, []byte(pluginResPath)) {
		return false, errors.New("project.godot verification failed after enabling plugin")
	}
	return true, nil
}

func replaceFileSafely(path string, content []byte) error {
	dir := filepath.Dir(path)
	tmp, err := os.CreateTemp(dir, ".godot-mcp-project-*.tmp")
	if err != nil {
		return err
	}
	tmpPath := tmp.Name()
	cleanup := true
	defer func() {
		if cleanup {
			_ = os.Remove(tmpPath)
		}
	}()
	if _, err := tmp.Write(content); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}

	backup := fmt.Sprintf("%s.godot-mcp-backup-%d", path, os.Getpid())
	_ = os.Remove(backup)
	if err := os.Rename(path, backup); err != nil {
		return err
	}
	if err := os.Rename(tmpPath, path); err != nil {
		_ = os.Rename(backup, path)
		return err
	}
	cleanup = false
	if err := os.Remove(backup); err != nil {
		return fmt.Errorf("project.godot updated but temporary backup cleanup failed: %w", err)
	}
	return nil
}

func writeJSONResult(path string, result installResult) error {
	data, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil && filepath.Dir(path) != "." {
		return err
	}
	return os.WriteFile(path, append(data, '\n'), 0o644)
}
