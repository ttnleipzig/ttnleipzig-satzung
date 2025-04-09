package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strings"
)

// OpenAI API constants
const openAIURL = "https://api.openai.com/v1/chat/completions"
const openAIModel = "gpt-4"

// OpenAI API key from environment variables
var openAIAPIKey = os.Getenv("OPENAI_API_KEY")

// Struct for OpenAI API request
type OpenAIRequest struct {
	Model    string `json:"model"`
	Messages []struct {
		Role    string `json:"role"`
		Content string `json:"content"`
	} `json:"messages"`
	MaxTokens   int     `json:"max_tokens"`
	Temperature float32 `json:"temperature"`
}

// Struct for OpenAI API response
type OpenAIResponse struct {
	Choices []struct {
		Message struct {
			Content string `json:"content"`
		} `json:"message"`
	} `json:"choices"`
}

// Struct for translations
type Translations struct {
	NoCommitsMessage string `json:"noCommitsMessage"`
	Feat             string `json:"feat"`
	Fix              string `json:"fix"`
	Docs             string `json:"docs"`
	Chore            string `json:"chore"`
	Refactor         string `json:"refactor"`
	Style            string `json:"style"`
	Test             string `json:"test"`
	CommitTypePrefix string `json:"commitTypePrefix"`
	ChangelogCreated string `json:"changelogCreated"`
	ChangelogHeader  string `json:"changelogHeader"`
}

var translations Translations

func main() {
	// Add language and filename as options
	lang := flag.String("lang", "en", "Language for translations (e.g., en, de, es, fr, it, ja, pt, zh)")
	changelogFile := flag.String("file", "CHANGELOG.md", "Name of the changelog file")
	flag.Parse()

	// Load translations
	loadTranslations(*lang)

	// Create changelog header
	createChangelogHeader(*changelogFile)

	// Retrieve and reverse Git tags
	tags, err := getGitTags()
	if err != nil {
		log.Fatalf("Error retrieving Git tags: %v", err)
	}

	// Iterate over each Git tag
	for i := 0; i < len(tags); i++ {
		var commits []string
		var date string

		if i == len(tags)-1 {
			// Retrieve commits for the first tag
			commits, err = getCommitsForTag(tags[i])
			if err != nil {
				log.Fatalf("Error retrieving commits for tag %s: %v", tags[i], err)
			}
			date, err = getTagDate(tags[i])
			if err != nil {
				log.Fatalf("Error retrieving date for tag %s: %v", tags[i], err)
			}
		} else {
			// Retrieve commits between tags
			commits, err = getCommitsBetweenTags(tags[i+1], tags[i])
			if err != nil {
				log.Fatalf("Error retrieving commits between tags %s and %s: %v", tags[i+1], tags[i], err)
			}
			date, err = getTagDate(tags[i])
			if err != nil {
				log.Fatalf("Error retrieving date for tag %s: %v", tags[i], err)
			}
		}

		if len(commits) == 0 {
			fmt.Printf(translations.NoCommitsMessage+"\n", tags[i])
			continue
		}

		appendToChangelog(*changelogFile, fmt.Sprintf("## [%s] - %s\n", tags[i], date))

		semanticGroups := make(map[string][]string)

		for _, commit := range commits {
			if isSemanticCommit(commit) {
				group := getCommitType(commit)
				translatedCommit, err := translateToSimpleLanguage(commit, *lang)
				if err != nil {
					log.Fatalf("Error translating commit: %v", err)
				}
				// Translate the commit type
				translatedGroup := translateCommitType(group)
				semanticGroups[translatedGroup] = append(semanticGroups[translatedGroup], translatedCommit)
			}
		}

		// Insert commit groupings into the changelog file
		for group, messages := range semanticGroups {
			appendToChangelog(*changelogFile, fmt.Sprintf("\n### %s\n\n", group))
			for _, message := range messages {
				lines := strings.Split(message, "\n")
				for _, line := range lines {
					if strings.TrimSpace(line) != "" {
						appendToChangelog(*changelogFile, fmt.Sprintf("- %s\n", line))
					}
				}
			}
		}

		appendToChangelog(*changelogFile, "\n")
	}

	fmt.Printf(translations.ChangelogCreated+"\n", *changelogFile)
}

func loadTranslations(lang string) {
	filePath := fmt.Sprintf("./Scripts/Translations/%s.json", lang)
	file, err := os.Open(filePath)
	if err != nil {
		log.Fatalf("Error loading translations: %v", err)
	}
	defer file.Close()

	decoder := json.NewDecoder(file)
	if err := decoder.Decode(&translations); err != nil {
		log.Fatalf("Error decoding translations: %v", err)
	}
}

func createChangelogHeader(changelogFile string) {
	err := os.WriteFile(changelogFile, []byte(fmt.Sprintf("# Changelog\n\n%s\n\n", translations.ChangelogHeader)), 0644)
	if err != nil {
		log.Fatalf("Error creating changelog header: %v", err)
	}
}

func appendToChangelog(changelogFile, content string) {
	file, err := os.OpenFile(changelogFile, os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		log.Fatalf("Error opening changelog file: %v", err)
	}
	defer file.Close()

	_, err = file.WriteString(content)
	if err != nil {
		log.Fatalf("Error writing to changelog file: %v", err)
	}
}

func getGitTags() ([]string, error) {
	cmd := exec.Command("git", "tag", "--sort=v:refname")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("Error retrieving Git tags: %v", err)
	}

	tags := strings.Split(string(output), "\n")
	if len(tags) > 0 && tags[len(tags)-1] == "" {
		tags = tags[:len(tags)-1]
	}

	for i, j := 0, len(tags)-1; i < j; i, j = i+1, j-1 {
		tags[i], tags[j] = tags[j], tags[i]
	}

	return tags, nil
}

func getTagDate(tag string) (string, error) {
	cmd := exec.Command("git", "log", "-1", "--format=%ai", tag)
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("Error retrieving date for tag %s: %v", tag, err)
	}
	date := strings.Fields(string(output))[0]
	return date, nil
}

func getCommitsForTag(tag string) ([]string, error) {
	cmd := exec.Command("git", "log", fmt.Sprintf("%s^..%s", tag, tag), "--pretty=format:%B")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("Error retrieving commits for tag %s: %v", tag, err)
	}

	commits := strings.Split(string(output), "\n\n")
	return commits, nil
}

func getCommitsBetweenTags(oldTag, newTag string) ([]string, error) {
	cmd := exec.Command("git", "log", fmt.Sprintf("%s..%s", oldTag, newTag), "--pretty=format:%B")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("Error retrieving commits between tags %s and %s: %v", oldTag, newTag, err)
	}

	commits := strings.Split(string(output), "\n\n")
	return commits, nil
}

func isSemanticCommit(commit string) bool {
	return strings.HasPrefix(commit, "feat") || strings.HasPrefix(commit, "fix") || strings.HasPrefix(commit, "docs") ||
		strings.HasPrefix(commit, "chore") || strings.HasPrefix(commit, "refactor") || strings.HasPrefix(commit, "style") ||
		strings.HasPrefix(commit, "test")
}

func getCommitType(commit string) string {
	parts := strings.SplitN(commit, ":", 2)
	if len(parts) > 0 {
		commitType := parts[0]
		if strings.Contains(commitType, "(") {
			commitType = strings.Split(commitType, "(")[0]
		}
		return commitType
	}
	return "unknown"
}

func translateCommitType(commitType string) string {
	switch commitType {
	case "feat":
		return translations.Feat
	case "fix":
		return translations.Fix
	case "docs":
		return translations.Docs
	case "chore":
		return translations.Chore
	case "refactor":
		return translations.Refactor
	case "style":
		return translations.Style
	case "test":
		return translations.Test
	default:
		return "Unknown"
	}
}

func translateToSimpleLanguage(text string, lang string) (string, error) {
	if openAIAPIKey == "" {
		return "", fmt.Errorf("Error: No OpenAI API key found. Set OPENAI_API_KEY.")
	}

	// Remove the prefix before translation
	parts := strings.SplitN(text, ":", 2)
	if len(parts) > 1 {
		text = strings.TrimSpace(parts[1])
	}

	systemPrompt := fmt.Sprintf("You are a translator who translates semantic commit messages into simple %s. Write as if the command has already been executed.", lang)

	request := OpenAIRequest{
		Model:       openAIModel,
		MaxTokens:   100,
		Temperature: 0.5,
		Messages: []struct {
			Role    string `json:"role"`
			Content string `json:"content"`
		}{
			{
				Role:    "system",
				Content: systemPrompt,
			},
			{
				Role:    "user",
				Content: text,
			},
		},
	}

	requestBody, err := json.Marshal(request)
	if err != nil {
		return "", fmt.Errorf("Error creating request body: %v", err)
	}

	req, err := http.NewRequest("POST", openAIURL, bytes.NewBuffer(requestBody))
	if err != nil {
		return "", fmt.Errorf("Error creating request: %v", err)
	}

	req.Header.Set("Authorization", "Bearer "+openAIAPIKey)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("Error sending request: %v", err)
	}
	defer resp.Body.Close()

	responseBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("Error reading response: %v", err)
	}

	var openAIResponse OpenAIResponse
	if err := json.Unmarshal(responseBody, &openAIResponse); err != nil {
		return "", fmt.Errorf("Error parsing OpenAI response: %v\nResponse: %s", err, string(responseBody))
	}

	return openAIResponse.Choices[0].Message.Content, nil
}
