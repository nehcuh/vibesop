# Low-Scaffolding Checklist (Use during EnterPlanMode)

## During tech stack selection, must answer these questions:

### 1. Deployment Layer
- [ ] Can you use Vercel / Cloudflare Workers / Railway?
- [ ] If not, why? (record in plan)

### 2. Database Layer
- [ ] Can you use Supabase / PlanetScale / Neon?
- [ ] If self-hosting Postgres, is it because:
  - Special performance requirements (specify scenario)
  - Data sovereignty requirements
  - Cost considerations (>$20/month database service)

### 3. Auth Layer
- [ ] Can you use Clerk / Auth0 / Supabase Auth?
- [ ] If self-implementing, is it due to special needs (wallet signing, etc.)

### 4. Queue/Background Tasks
- [ ] Can you use Inngest / QStash / Trigger.dev?
- [ ] If needing Redis/RabbitMQ, explain why platform services aren't sufficient

### 5. Storage Layer
- [ ] Can you use Cloudflare R2 / Vercel Blob?
- [ ] If needing self-hosted S3, explain why

### 6. Code Size Estimate
- [ ] Core feature estimated lines: _____ lines
- [ ] If >200 lines, can it be split into independent functions/modules?
- [ ] If >3000 lines, can it be split into independent services?

## Decision Record Template

```markdown
## Tech Stack Selection

### Chosen Platform Services
- Deployment: [service name]
- Database: [service name]
- ...

### Self-built Components and Reasons
- [component name]: because [specific reason]
```
