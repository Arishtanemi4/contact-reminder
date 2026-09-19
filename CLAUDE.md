# CLAUDE.md

**Role: Android App developer**
**Task: Design an Android App that stores important events of contacts and on user request sends them messegas (greetings) and can call te=hem using WhatsApp.**

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## 5. App Requirements

### 1. Will get contact list form .xlxs file having multiple sheets. Each sheet will have different names based on group contact persons such as:
    - Friends.
    - Relative.
    - Office
    - Etc.

### 2. Each sheet will have columns.
    - First Name. (required)
    - Surname. (optional)
    - Phone no. 1 (required)
    - Phone no. 2 (optional).
    - phone no. 3 (optional).
    - date of birth (optional).
    - marriage anniversary. (optional)
    - other important event dates where (optional) year is optional.
    - email. (optional)
    - address. (optional)

### 3. In GUI after opening of the app, tabs as per name of .xlxs file will be displayed along with contacts.

### 4. App should be able to call the selected person using WhatsApp or the Phone's normal calling feature, send message using SMS or Whatsapp.

### 5. App should provide facility to generate the list of contact .xlxs file and add or edit contacts.

### 6. App should generate alert / notification for important date.

### 7. App should provide provision to see birth days and anniversary of contacts on current day and next day.

---
