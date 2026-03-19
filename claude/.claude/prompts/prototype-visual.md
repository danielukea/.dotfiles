## Verification Protocol

After achieving each outcome:

1. **Test**: Write a test for the core behavior. Run it.
2. **Visual**: Use agent-browser to screenshot the relevant page.
   Confirm the UI looks correct and matches expectations.
   - `agent-browser open <url>`
   - `agent-browser screenshot <path>`
3. **DX review**: Look at the public interface you created (method signatures,
   API shape, component props). Is it minimal and intuitive? If not, simplify
   before marking done.
4. Only mark done if all checks pass.
