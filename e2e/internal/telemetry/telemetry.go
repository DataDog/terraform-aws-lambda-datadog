// Package telemetry polls the Datadog API for spans and logs emitted by an e2e
// workload and asserts the identifying tags carried on the ingested telemetry. It is
// runner-agnostic: it takes plain values and returns errors, so it has no test-framework
// dependency. Mirrors the cloud-run-telemetry-checker reference (poll 15s x 20).
package telemetry

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"slices"
	"strings"
	"time"
)

const (
	pollInterval = 15 * time.Second
	maxAttempts  = 20
	lookback     = 15 * time.Minute
)

// Client talks to the Datadog spans and logs search APIs.
type Client struct {
	Site   string
	APIKey string
	AppKey string
	HTTP   *http.Client
}

// NewClient builds a telemetry client for the given Datadog site (e.g. datadoghq.com).
func NewClient(site, apiKey, appKey string) *Client {
	return &Client{
		Site:   site,
		APIKey: apiKey,
		AppKey: appKey,
		HTTP:   &http.Client{Timeout: 30 * time.Second},
	}
}

// Event is a single ingested span or log, flattened to the fields we assert on.
type Event struct {
	// Attrs holds top-level string attributes (service, env, version, ...).
	Attrs map[string]string
	// Tags holds "key:value" tag strings attached to the event.
	Tags []string
}

// Has reports whether the event carries key=value, either as a structured attribute
// or as a "key:value" tag. This is how we assert identity rather than mere existence.
func (e Event) Has(key, value string) bool {
	if v, ok := e.Attrs[key]; ok && v == value {
		return true
	}
	return slices.Contains(e.Tags, key+":"+value)
}

func (c *Client) apiHost() string {
	return "https://api." + c.Site
}

func (c *Client) post(ctx context.Context, path string, body any) ([]byte, error) {
	payload, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.apiHost()+path, bytes.NewReader(payload))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("DD-API-KEY", c.APIKey)
	req.Header.Set("DD-APPLICATION-KEY", c.AppKey)

	resp, err := c.HTTP.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(resp.Body)
	if resp.StatusCode/100 != 2 {
		return nil, fmt.Errorf("datadog API %s returned %d: %s", path, resp.StatusCode, string(data))
	}

	return data, nil
}

// searchResponse models the shared shape of the v2 spans/logs search responses.
type searchResponse struct {
	Data []struct {
		Attributes struct {
			Service string   `json:"service"`
			Env     string   `json:"env"`
			Version string   `json:"version"`
			Tags    []string `json:"tags"`
			// Logs nest their structured attributes one level deeper.
			Attributes map[string]json.RawMessage `json:"attributes"`
		} `json:"attributes"`
	} `json:"data"`
}

func parseEvents(data []byte) ([]Event, error) {
	var resp searchResponse
	if err := json.Unmarshal(data, &resp); err != nil {
		return nil, err
	}
	events := make([]Event, 0, len(resp.Data))
	for _, d := range resp.Data {
		attrs := map[string]string{}
		if d.Attributes.Service != "" {
			attrs["service"] = d.Attributes.Service
		}
		if d.Attributes.Env != "" {
			attrs["env"] = d.Attributes.Env
		}
		if d.Attributes.Version != "" {
			attrs["version"] = d.Attributes.Version
		}
		for k, raw := range d.Attributes.Attributes {
			var s string
			if json.Unmarshal(raw, &s) == nil {
				attrs[k] = s
			}
		}
		events = append(events, Event{Attrs: attrs, Tags: d.Attributes.Tags})
	}

	return events, nil
}

func (c *Client) window() (string, string) {
	now := time.Now()
	return now.Add(-lookback).Format(time.RFC3339), now.Format(time.RFC3339)
}

// SearchSpans returns spans matching the query within the lookback window.
func (c *Client) SearchSpans(ctx context.Context, query string) ([]Event, error) {
	from, to := c.window()
	body := map[string]any{
		"data": map[string]any{
			"type": "search_request",
			"attributes": map[string]any{
				"filter": map[string]any{"query": query, "from": from, "to": to},
				"page":   map[string]any{"limit": 10},
			},
		},
	}
	data, err := c.post(ctx, "/api/v2/spans/events/search", body)
	if err != nil {
		return nil, err
	}

	return parseEvents(data)
}

// SearchLogs returns logs matching the query within the lookback window.
func (c *Client) SearchLogs(ctx context.Context, query string) ([]Event, error) {
	from, to := c.window()
	body := map[string]any{
		"filter": map[string]any{"query": query, "from": from, "to": to},
		"page":   map[string]any{"limit": 10},
	}
	data, err := c.post(ctx, "/api/v2/logs/events/search", body)
	if err != nil {
		return nil, err
	}

	return parseEvents(data)
}

// Identity is the set of tags expected on every ingested event for a workload.
type Identity struct {
	Service string
	Env     string
	Version string
	RunID   string
}

func (id Identity) matches(e Event) bool {
	return e.Has("service", id.Service) &&
		e.Has("env", id.Env) &&
		e.Has("version", id.Version) &&
		e.Has("one_e2e_run_id", id.RunID)
}

// WaitForMatching polls the given search function on a bounded budget until at least one
// returned event carries the full identity, then returns it. It retries the cloud
// (transient query errors, propagation delay) but never declares success without a match.
func (c *Client) WaitForMatching(
	ctx context.Context,
	label string,
	search func(context.Context, string) ([]Event, error),
	query string,
	id Identity,
) (Event, error) {
	var lastErr error
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		events, err := search(ctx, query)
		if err != nil {
			lastErr = err
		} else {
			for _, e := range events {
				if id.matches(e) {
					return e, nil
				}
			}
			if len(events) > 0 {
				lastErr = fmt.Errorf("%d %s found for query %q but none carried the expected identity %+v", len(events), label, query, id)
			} else {
				lastErr = fmt.Errorf("no %s found yet for query %q", label, query)
			}
		}
		if attempt < maxAttempts {
			select {
			case <-ctx.Done():
				return Event{}, ctx.Err()
			case <-time.After(pollInterval):
			}
		}
	}

	return Event{}, fmt.Errorf("[%s] timed out after %d attempts (%s): %w",
		label, maxAttempts, time.Duration(maxAttempts)*pollInterval, lastErr)
}

// SpanQuery / LogQuery build the run-id-scoped search queries.
func SpanQuery(id Identity) string {
	return strings.Join([]string{"service:" + id.Service, "one_e2e_run_id:" + id.RunID}, " ")
}

func LogQuery(id Identity) string {
	return strings.Join([]string{"service:" + id.Service, "one_e2e_run_id:" + id.RunID}, " ")
}
