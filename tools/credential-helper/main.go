package main

import (
	"encoding/binary"
	"errors"
	"fmt"
	"os"
	"runtime"
	"strings"
	"syscall"
	"unicode/utf16"
	"unicode/utf8"
	"unsafe"
)

const (
	defaultTarget                         = "godot-mcp-chatgpt/0.4/OpenAI/Tunnel/APIKey"
	credentialValueEnv                    = "GODOT_MCP_CHATGPT_CREDENTIAL_VALUE"
	credTypeGeneric                       = 1
	credPersistLocalMachine               = 2
	maxCredentialBlobBytes                = 2560
	errorNotFound           syscall.Errno = 1168
)

type filetime struct{ LowDateTime, HighDateTime uint32 }
type credential struct {
	Flags              uint32
	Type               uint32
	TargetName         *uint16
	Comment            *uint16
	LastWritten        filetime
	CredentialBlobSize uint32
	CredentialBlob     *byte
	Persist            uint32
	AttributeCount     uint32
	Attributes         uintptr
	TargetAlias        *uint16
	UserName           *uint16
}

var (
	advapi32        = syscall.NewLazyDLL("advapi32.dll")
	procCredWriteW  = advapi32.NewProc("CredWriteW")
	procCredReadW   = advapi32.NewProc("CredReadW")
	procCredDeleteW = advapi32.NewProc("CredDeleteW")
	procCredFree    = advapi32.NewProc("CredFree")
)

func main() {
	if runtime.GOOS != "windows" {
		fatal("WINDOWS_REQUIRED")
	}
	if len(os.Args) < 2 {
		fatal("USAGE: credential-helper <read|write|delete|present> [--test-target <target>]")
	}
	target, err := resolveTarget(os.Args[2:])
	if err != nil {
		fatal(err.Error())
	}
	switch os.Args[1] {
	case "read":
		value, present, err := readCredential(target)
		if err != nil {
			fatal(err.Error())
		}
		if !present {
			os.Exit(3)
		}
		fmt.Print(value)
	case "present":
		_, present, err := readCredential(target)
		if err != nil {
			fatal(err.Error())
		}
		if present {
			fmt.Print("1")
		} else {
			fmt.Print("0")
		}
	case "write":
		value := os.Getenv(credentialValueEnv)
		if err := validateSecret(value); err != nil {
			fatal(err.Error())
		}
		if err := writeCredential(target, value); err != nil {
			fatal(err.Error())
		}
	case "delete":
		if err := deleteCredential(target); err != nil {
			fatal(err.Error())
		}
	default:
		fatal("UNKNOWN_COMMAND")
	}
}

func resolveTarget(args []string) (string, error) {
	if len(args) == 0 {
		return defaultTarget, nil
	}
	if len(args) != 2 || args[0] != "--test-target" {
		return "", errors.New("INVALID_TARGET_ARGUMENTS")
	}
	target := strings.TrimSpace(args[1])
	if !strings.HasPrefix(target, "godot-mcp-chatgpt/test/") || len(target) > 240 {
		return "", errors.New("INVALID_TEST_TARGET")
	}
	return target, nil
}

func validateSecret(value string) error {
	if value == "" || value != strings.TrimSpace(value) || len([]byte(value)) > 1200 {
		return errors.New("INVALID_SECRET")
	}
	if strings.IndexFunc(value, func(r rune) bool { return r == 0 || r == '\r' || r == '\n' || r == '\t' || r == ' ' }) >= 0 {
		return errors.New("INVALID_SECRET")
	}
	return nil
}

func readCredential(target string) (string, bool, error) {
	targetPtr, err := syscall.UTF16PtrFromString(target)
	if err != nil {
		return "", false, err
	}
	var cred *credential
	result, _, callErr := procCredReadW.Call(uintptr(unsafe.Pointer(targetPtr)), credTypeGeneric, 0, uintptr(unsafe.Pointer(&cred)))
	runtime.KeepAlive(targetPtr)
	if result == 0 {
		if errnoIs(callErr, errorNotFound) {
			return "", false, nil
		}
		return "", false, fmt.Errorf("CredReadW: %v", callErr)
	}
	if cred == nil {
		return "", false, errors.New("CredReadW returned nil credential")
	}
	defer procCredFree.Call(uintptr(unsafe.Pointer(cred)))
	if cred.CredentialBlobSize > maxCredentialBlobBytes {
		return "", false, errors.New("credential blob too large")
	}
	if cred.CredentialBlobSize == 0 {
		return "", true, nil
	}
	if cred.CredentialBlob == nil {
		return "", false, errors.New("credential blob pointer is nil")
	}
	blob := append([]byte(nil), unsafe.Slice(cred.CredentialBlob, int(cred.CredentialBlobSize))...)
	value, err := decodeCredentialText(blob)
	if err != nil {
		return "", false, err
	}
	return value, true, nil
}

func writeCredential(target, value string) error {
	blob := encodeCredentialText(value)
	if len(blob) == 0 || len(blob) > maxCredentialBlobBytes {
		return errors.New("credential blob invalid")
	}
	targetPtr, err := syscall.UTF16PtrFromString(target)
	if err != nil {
		return err
	}
	userPtr, err := syscall.UTF16PtrFromString("godot-mcp-chatgpt")
	if err != nil {
		return err
	}
	commentPtr, _ := syscall.UTF16PtrFromString("OpenAI Secure MCP Tunnel Runtime API Key")
	cred := credential{Type: credTypeGeneric, TargetName: targetPtr, Comment: commentPtr, CredentialBlobSize: uint32(len(blob)), CredentialBlob: &blob[0], Persist: credPersistLocalMachine, UserName: userPtr}
	result, _, callErr := procCredWriteW.Call(uintptr(unsafe.Pointer(&cred)), 0)
	runtime.KeepAlive(targetPtr)
	runtime.KeepAlive(userPtr)
	runtime.KeepAlive(commentPtr)
	runtime.KeepAlive(blob)
	if result == 0 {
		return fmt.Errorf("CredWriteW: %v", callErr)
	}
	return nil
}

func deleteCredential(target string) error {
	targetPtr, err := syscall.UTF16PtrFromString(target)
	if err != nil {
		return err
	}
	result, _, callErr := procCredDeleteW.Call(uintptr(unsafe.Pointer(targetPtr)), credTypeGeneric, 0)
	runtime.KeepAlive(targetPtr)
	if result == 0 && !errnoIs(callErr, errorNotFound) {
		return fmt.Errorf("CredDeleteW: %v", callErr)
	}
	return nil
}

func encodeCredentialText(value string) []byte {
	units := utf16.Encode([]rune(value))
	blob := make([]byte, len(units)*2)
	for i, unit := range units {
		binary.LittleEndian.PutUint16(blob[i*2:], unit)
	}
	return blob
}

func decodeCredentialText(blob []byte) (string, error) {
	if len(blob) >= 2 && len(blob)%2 == 0 {
		pairs := len(blob) / 2
		zeroHigh := 0
		printable := 0
		for i := 0; i < len(blob); i += 2 {
			if blob[i+1] == 0 {
				zeroHigh++
				if blob[i] >= 0x20 && blob[i] <= 0x7e {
					printable++
				}
			}
		}
		if printable > 0 && zeroHigh*10 >= pairs*8 {
			units := make([]uint16, pairs)
			for i := range units {
				units[i] = binary.LittleEndian.Uint16(blob[i*2:])
			}
			for len(units) > 0 && units[len(units)-1] == 0 {
				units = units[:len(units)-1]
			}
			return string(utf16.Decode(units)), nil
		}
	}
	if !utf8.Valid(blob) {
		return "", errors.New("unsupported credential encoding")
	}
	return string(blob), nil
}

func errnoIs(err error, want syscall.Errno) bool {
	errno, ok := err.(syscall.Errno)
	return ok && errno == want
}
func fatal(message string) { fmt.Fprintln(os.Stderr, message); os.Exit(2) }
