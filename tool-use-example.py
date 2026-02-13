#!/usr/bin/env python3
"""
Example: Tool/Function calling with Ollama
Demonstrates how models can call external functions
"""

import json
import requests
from datetime import datetime

# Ollama API endpoint
OLLAMA_API = "http://localhost:11434/api/chat"

# Define available tools
TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "get_current_time",
            "description": "Get the current time",
            "parameters": {
                "type": "object",
                "properties": {
                    "timezone": {
                        "type": "string",
                        "description": "Timezone (e.g., 'UTC', 'America/New_York')",
                        "default": "UTC"
                    }
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "calculate",
            "description": "Perform a mathematical calculation",
            "parameters": {
                "type": "object",
                "properties": {
                    "expression": {
                        "type": "string",
                        "description": "Math expression to evaluate (e.g., '2 + 2', '10 * 5')"
                    }
                },
                "required": ["expression"]
            }
        }
    }
]

# Implement the actual functions
def get_current_time(timezone="UTC"):
    """Get current time in specified timezone"""
    return {"time": datetime.now().isoformat(), "timezone": timezone}

def calculate(expression):
    """Safely evaluate a math expression"""
    try:
        # WARNING: eval() is dangerous in production! Use a proper math parser
        result = eval(expression, {"__builtins__": {}}, {})
        return {"result": result, "expression": expression}
    except Exception as e:
        return {"error": str(e)}

# Function registry
FUNCTION_MAP = {
    "get_current_time": get_current_time,
    "calculate": calculate
}

def call_ollama(messages, model="qwen2.5-coder:14b", tools=None):
    """Call Ollama API with messages and optional tools"""
    payload = {
        "model": model,
        "messages": messages,
        "stream": False
    }
    if tools:
        payload["tools"] = tools

    response = requests.post(OLLAMA_API, json=payload)
    return response.json()

def execute_tool_call(tool_call):
    """Execute a tool call and return the result"""
    function_name = tool_call["function"]["name"]
    arguments = tool_call["function"]["arguments"]

    if function_name in FUNCTION_MAP:
        result = FUNCTION_MAP[function_name](**arguments)
        return json.dumps(result)
    else:
        return json.dumps({"error": f"Unknown function: {function_name}"})

def chat_with_tools(user_message, model="qwen2.5-coder:14b"):
    """
    Chat with the model, allowing it to use tools
    """
    messages = [
        {"role": "user", "content": user_message}
    ]

    print(f"User: {user_message}\n")

    # Initial call with tools available
    response = call_ollama(messages, model=model, tools=TOOLS)
    assistant_message = response["message"]

    # Check if model wants to use tools
    if "tool_calls" in assistant_message:
        print("🔧 Model is calling tools...\n")

        # Add assistant's tool call to messages
        messages.append(assistant_message)

        # Execute each tool call
        for tool_call in assistant_message["tool_calls"]:
            function_name = tool_call["function"]["name"]
            arguments = tool_call["function"]["arguments"]

            print(f"Calling: {function_name}({arguments})")

            # Execute the function
            result = execute_tool_call(tool_call)
            print(f"Result: {result}\n")

            # Add tool result to messages
            messages.append({
                "role": "tool",
                "content": result
            })

        # Get final response from model using tool results
        final_response = call_ollama(messages, model=model)
        final_message = final_response["message"]["content"]

        print(f"Assistant: {final_message}\n")
        return final_message
    else:
        # No tools needed, direct response
        content = assistant_message.get("content", "")
        print(f"Assistant: {content}\n")
        return content

if __name__ == "__main__":
    print("=" * 60)
    print("Ollama Tool Use Demo")
    print("=" * 60)
    print()

    # Example 1: Time query
    print("Example 1: Ask for current time")
    print("-" * 60)
    chat_with_tools("What's the current time?")

    # Example 2: Math calculation
    print("\nExample 2: Ask for calculation")
    print("-" * 60)
    chat_with_tools("What is 123 * 456?")

    # Example 3: Combined query
    print("\nExample 3: Combined query")
    print("-" * 60)
    chat_with_tools("What time is it and what is 2 to the power of 10?")

    print("\n" + "=" * 60)
    print("Demo complete!")
    print("=" * 60)
