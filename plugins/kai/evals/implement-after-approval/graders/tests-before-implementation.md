---
type: tool_order
before:
  tool: Bash
  input_match: 'git commit[^\n]*PAY-102: failing tests'
after:
  tool: Edit
  input_match: 'src/favorites\.js'
---
