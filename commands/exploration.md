# /exploration — Solution Quality Check

## Purpose
Before writing code, have Claude play CTO/architect role to challenge the solution's feasibility.

## When to Use
- About to implement a new feature
- Multiple solution approaches available
- Feeling "ready to start coding" but not quite sure

## Execution Steps

1. **Understand current solution**
   Ask user to describe in 1-2 sentences what they want to do

2. **CTO Challenge Mode**
   From tech leadership perspective:
   - "Why this approach instead of [alternative]?"
   - "What are the boundary conditions?"
   - "What happens in worst case?"
   - "Is there a simpler way to achieve the same goal?"
   - "What tech debt does this introduce?"

3. **Explore current code**
   - Search related code, understand existing patterns
   - Identify files that need modification
   - Estimate change scope

4. **Generate Go/No-Go recommendation**
   ```
   ## Exploration Conclusion

   ### Solution Assessment
   - Feasibility: [High/Medium/Low]
   - Complexity: [High/Medium/Low]
   - Risk: [High/Medium/Low]

   ### Key Questions (must answer)
   1. ...
   2. ...

   ### Recommendation
   [ ] Go - Ready to start planning
   [ ] Hold - Need to resolve [issue] first
   [ ] No-Go - Suggest alternative: [reason]
   ```

## Core Philosophy
"5 minutes of questioning before coding beats 5 hours of fixing after"
