package main

import (
	"context"
	"encoding/json"
	"log"

	"github.com/aws/aws-lambda-go/lambda"
)

// HandleRequest processes the lambda event
func HandleRequest(ctx context.Context, event json.RawMessage) error {
	log.Println("Hello, World!")

	return nil
}

func main() {
	lambda.Start(HandleRequest)
} 