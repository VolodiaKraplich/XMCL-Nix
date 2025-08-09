package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"
)

const (
	flakeFile = "flake.nix"
	repoOwner = "Voxelum"
	repoName  = "x-minecraft-launcher"
	arch      = "x64"
	timeout   = 15 * time.Second
	apiURL    = "https://api.github.com/repos/" + repoOwner + "/" + repoName + "/releases/latest"
)

var (
	versionRe = regexp.MustCompile(`(\s*xmclVersion\s*=\s*)"[^"]*"`)
	sha256Re  = regexp.MustCompile(`(\s*sha256\s*=\s*)"[^"]*"`)
)

type Release struct {
	TagName string `json:"tag_name"`
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	// Check file exists
	if _, err := os.Stat(flakeFile); os.IsNotExist(err) {
		return fmt.Errorf("file not found: %s", flakeFile)
	}

	// Get current version
	current, err := getCurrentVersion()
	if err != nil {
		return err
	}

	// Get latest version
	latest, err := getLatestVersion()
	if err != nil {
		return err
	}

	fmt.Printf("Current: %s, Latest: %s\n", current, latest)

	if current == latest {
		fmt.Println("Already up to date")
		return nil
	}

	// Get SHA256
	sha256, err := getSHA256(latest)
	if err != nil {
		return err
	}

	// Update file
	return updateFile(latest, sha256)
}

func getCurrentVersion() (string, error) {
	file, err := os.Open(flakeFile)
	if err != nil {
		return "", err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		if matches := regexp.MustCompile(`xmclVersion\s*=\s*"([^"]+)"`).FindStringSubmatch(scanner.Text()); matches != nil {
			return matches[1], nil
		}
	}
	return "", fmt.Errorf("version not found in %s", flakeFile)
}

func getLatestVersion() (string, error) {
	client := &http.Client{Timeout: timeout}
	resp, err := client.Get(apiURL)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return "", fmt.Errorf("API returned status %d", resp.StatusCode)
	}

	var release Release
	if err := json.NewDecoder(resp.Body).Decode(&release); err != nil {
		return "", err
	}

	return strings.TrimPrefix(release.TagName, "v"), nil
}

func getSHA256(version string) (string, error) {
	url := fmt.Sprintf("https://github.com/%s/%s/releases/download/v%s/xmcl-%s-%s.tar.xz.sha256",
		repoOwner, repoName, version, version, arch)

	client := &http.Client{Timeout: timeout}
	resp, err := client.Get(url)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return "", fmt.Errorf("SHA256 file not found (status %d)", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	return strings.TrimSpace(string(body)), nil
}

func updateFile(version, sha256 string) error {
	// Read file
	content, err := os.ReadFile(flakeFile)
	if err != nil {
		return err
	}

	text := string(content)

	// Update version
	text = versionRe.ReplaceAllString(text, `${1}"`+version+`"`)

	// Update SHA256
	text = sha256Re.ReplaceAllString(text, `${1}"`+sha256+`"`)

	// Write back
	if err := os.WriteFile(flakeFile, []byte(text), 0644); err != nil {
		return err
	}

	fmt.Printf("Updated to version %s\n", version)
	return nil
}
