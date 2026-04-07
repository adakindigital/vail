package main

import "github.com/adakindigital/vail/cmd"

// Set at build time via GoReleaser ldflags:
//   -X main.version=v1.0.0 -X main.commit=abc1234 -X main.date=2026-01-01
var (
	version = "dev"
	commit  = "none"
	date    = "unknown"
)

func main() {
	cmd.SetVersion(version, commit, date)
	cmd.Execute()
}
