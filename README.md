# AI Autonomous Agent (for Godot 4.5+)

**AI Autonomous Agent** is a powerful plugin that embeds an autonomous coding agent directly into the Godot Editor. Unlike simple chat wrappers, this agent has **agency**: it can read your project files, write code, list directories, and even check for syntax errors autonomously to complete complex tasks.

## Features

*   **Agency**: The agent can plan and execute multi-step tasks.
*   **File System Access**: Can list directories and read any file in your project.
*   **Code Writing**: Can create new scripts or modify existing ones.
*   **Syntax Checking**: Automatically verifies code for errors before finishing a task.
*   **Multiple Models**: Support for **Gemini**, **Ollama**, **OpenRouter**, and **OpenWebUI**.
*   **Context Aware**: Knows it is working inside Godot 4.5+ and uses GDScript best practices.

## Installation

1.  Copy the `ai_autonomous_agent` folder into your project's `addons/` directory.
2.  Enable the plugin in **Project > Project Settings > Plugins**.
3.  Open the **AI Agent** bottom panel.
4.  Configure your preferred LLM provider (e.g., local Ollama or Gemini API key).

## Quick Start

1.  Click **"New Agent"** in the bottom panel.
2.  Type your request (e.g., *"Create a player controller with double jump"*).
3.  Watch the agent work! It will verify files, write code, and confirm when it's done.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Credits

Based on the **AI Assistant Hub** plugin originally created by **[Flamx Games](https://github.com/FlamxGames/godot-ai-assistant-hub)**.

---

**Author:** Vitor Zanatta Walter
**Version:** 1.0.0
