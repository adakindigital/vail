package client

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// Message is a single entry in a conversation.
// Content is any because tool-call-only assistant turns have null content.
type Message struct {
	Role       string       `json:"role"`
	Content    any          `json:"content"`
	ToolCalls  []APIToolCall `json:"tool_calls,omitempty"`
	ToolCallID string       `json:"tool_call_id,omitempty"`
}

// APIToolCall is the tool call format the model emits and we echo back in history.
type APIToolCall struct {
	ID       string `json:"id"`
	Type     string `json:"type"`
	Function struct {
		Name      string `json:"name"`
		Arguments string `json:"arguments"`
	} `json:"function"`
}

// ToolDef is the function definition sent to the model in a tools-enabled request.
type ToolDef struct {
	Type     string       `json:"type"`
	Function ToolFunction `json:"function"`
}

// ToolFunction describes a single callable function.
type ToolFunction struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	Parameters  any    `json:"parameters"`
}

// ToolCall is a parsed tool call from the model response.
type ToolCall struct {
	ID        string
	Name      string
	Arguments string // raw JSON — callers decode what they need
}

// StreamResult is what StreamWithTools returns when the model finishes a turn.
type StreamResult struct {
	Content   string
	ToolCalls []ToolCall
}

type Client struct {
	endpoint string
	apiKey   string
	model    string
	http     *http.Client
}

func New(endpoint, apiKey, model string) *Client {
	return &Client{
		endpoint: strings.TrimRight(endpoint, "/"),
		apiKey:   apiKey,
		model:    model,
		// No total timeout — long-thinking responses can take several minutes.
		// ResponseHeaderTimeout catches a dead server quickly without killing slow responses.
		http: &http.Client{
			Transport: &http.Transport{
				ResponseHeaderTimeout: 30 * time.Second,
			},
		},
	}
}

// Stream sends messages and calls onToken for each streamed token.
// Returns full response text when complete.
func (c *Client) Stream(messages []Message, onToken func(string)) (string, error) {
	result, err := c.StreamWithTools(messages, nil, onToken)
	return result.Content, err
}

// StreamWithTools sends messages with optional tool definitions.
// If the model makes tool calls, they are returned in StreamResult.ToolCalls.
func (c *Client) StreamWithTools(messages []Message, tools []ToolDef, onToken func(string)) (StreamResult, error) {
	body := map[string]any{
		"model":    c.model,
		"messages": messages,
		"stream":   true,
	}
	if len(tools) > 0 {
		body["tools"] = tools
	}

	resp, err := c.post(body)
	if err != nil {
		return StreamResult{}, err
	}
	defer resp.Body.Close()

	return c.parseStream(resp.Body, onToken)
}

// post sends a JSON POST to /v1/chat/completions and returns the raw response.
func (c *Client) post(body map[string]any) (*http.Response, error) {
	data, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequest("POST", c.endpoint+"/v1/chat/completions", bytes.NewReader(data))
	if err != nil {
		return nil, err
	}

	req.Header.Set("Content-Type", "application/json")
	if c.apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+c.apiKey)
	}

	resp, err := c.http.Do(req)
	if err != nil {
		if isConnErr(err) {
			return nil, fmt.Errorf("cannot reach Vail server — is it running?")
		}
		return nil, fmt.Errorf("request failed: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()
		return nil, fmt.Errorf("server returned %d: %s", resp.StatusCode, string(body))
	}

	return resp, nil
}

// parseStream reads an SSE response body, firing onToken for content tokens and
// accumulating tool call deltas. Returns the full result when the stream ends.
func (c *Client) parseStream(body io.Reader, onToken func(string)) (StreamResult, error) {
	type toolCallDelta struct {
		Index    int    `json:"index"`
		ID       string `json:"id"`
		Type     string `json:"type"`
		Function struct {
			Name      string `json:"name"`
			Arguments string `json:"arguments"`
		} `json:"function"`
	}

	type chunk struct {
		Choices []struct {
			Delta struct {
				Content   string          `json:"content"`
				ToolCalls []toolCallDelta `json:"tool_calls"`
			} `json:"delta"`
			FinishReason string `json:"finish_reason"`
		} `json:"choices"`
		Error *struct {
			Message string `json:"message"`
		} `json:"error"`
	}

	var (
		content      strings.Builder
		tcAccum      = map[int]*ToolCall{} // indexed by tool call index
		receivedDone = false
	)

	scanner := bufio.NewScanner(body)

	for scanner.Scan() {
		line := scanner.Text()

		if !strings.HasPrefix(line, "data: ") {
			continue
		}

		payload := strings.TrimPrefix(line, "data: ")
		if payload == "[DONE]" {
			receivedDone = true
			break
		}

		var c chunk
		if err := json.Unmarshal([]byte(payload), &c); err != nil {
			continue
		}

		if c.Error != nil {
			return StreamResult{Content: content.String()}, fmt.Errorf("model error: %s", c.Error.Message)
		}

		if len(c.Choices) == 0 {
			continue
		}

		delta := c.Choices[0].Delta

		// Accumulate content tokens
		if delta.Content != "" {
			content.WriteString(delta.Content)
			if onToken != nil {
				onToken(delta.Content)
			}
		}

		// Accumulate tool call deltas — arguments arrive across multiple chunks
		for _, tcd := range delta.ToolCalls {
			tc := tcAccum[tcd.Index]
			if tc == nil {
				tc = &ToolCall{}
				tcAccum[tcd.Index] = tc
			}
			if tcd.ID != "" {
				tc.ID = tcd.ID
			}
			if tcd.Function.Name != "" {
				tc.Name += tcd.Function.Name
			}
			if tcd.Function.Arguments != "" {
				tc.Arguments += tcd.Function.Arguments
			}
		}
	}

	if err := scanner.Err(); err != nil {
		return StreamResult{Content: content.String()}, fmt.Errorf("stream interrupted: %w", err)
	}

	if !receivedDone {
		if content.Len() == 0 && len(tcAccum) == 0 {
			return StreamResult{}, fmt.Errorf("server crashed before generating a response — restart the Vail server")
		}
		return StreamResult{Content: content.String()}, fmt.Errorf("server crashed mid-response — output may be incomplete")
	}

	// Flatten accumulated tool calls into order
	result := StreamResult{Content: content.String()}
	for i := 0; i < len(tcAccum); i++ {
		if tc, ok := tcAccum[i]; ok {
			result.ToolCalls = append(result.ToolCalls, *tc)
		}
	}

	return result, nil
}

// isConnErr returns true for errors that indicate the server isn't reachable.
func isConnErr(err error) bool {
	s := err.Error()
	return strings.Contains(s, "connection refused") ||
		strings.Contains(s, "no such host") ||
		strings.Contains(s, "connect: connection refused")
}
