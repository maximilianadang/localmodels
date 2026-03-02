#!/bin/bash
# Quick test of Ollama tool/function calling

echo "🔧 Testing Ollama Tool Use"
echo "================================"
echo ""

# Test if Ollama is running
if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "❌ Ollama not running. Start with: ./docker-deploy.sh"
    exit 1
fi

echo "Asking model to use a calculator tool..."
echo ""

# Send a request with a tool definition
curl -s http://localhost:11434/api/chat -d '{
  "model": "qwen2.5-coder:14b",
  "messages": [
    {
      "role": "user",
      "content": "What is 15 multiplied by 37?"
    }
  ],
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "calculate",
        "description": "Perform mathematical calculations",
        "parameters": {
          "type": "object",
          "properties": {
            "expression": {
              "type": "string",
              "description": "Math expression to evaluate"
            }
          },
          "required": ["expression"]
        }
      }
    }
  ],
  "stream": false
}' | jq '.message'

echo ""
echo "================================"
echo ""
echo "The model should respond with a tool_call for 'calculate'"
echo "In a real app, you'd execute that function and send the result back."
