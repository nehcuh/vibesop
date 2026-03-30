# Architecture Diagrams

**Version**: 1.0.0  
**Last Updated**: 2026-03-30

---

## System Overview

```mermaid
graph TB
    subgraph "User Interface"
        CLI[vibe CLI]
        Agent[Claude Code Agent]
    end
    
    subgraph "Routing Layer"
        SR[SkillRouter]
        CS[CandidateSelector]
        PA[PreferenceAnalyzer]
        PE[ParallelExecutor]
    end
    
    subgraph "Routing Layers"
        L0[Layer 0: AI Triage]
        L1[Layer 1: Explicit]
        L2[Layer 2: Scenario]
        L3[Layer 3: Semantic]
        L4[Layer 4: Fuzzy]
    end
    
    subgraph "Data Sources"
        REG[Skill Registry]
        POL[Selection Policy]
        HIST[Preference History]
        CACHE[Cache Manager]
    end
    
    subgraph "Execution"
        S1[Skill 1]
        S2[Skill 2]
        S3[Skill N]
    end
    
    CLI --> SR
    Agent --> SR
    SR --> L0
    L0 --> L1
    L1 --> L2
    L2 --> L3
    L3 --> L4
    
    L0 --> REG
    L1 --> POL
    L2 --> REG
    L3 --> REG
    L4 --> REG
    
    SR --> CS
    CS --> PA
    PA --> HIST
    CS --> PE
    
    SR --> CACHE
    PE --> S1
    PE --> S2
    PE --> S3
```

---

## Skill Router Flow

```mermaid
flowchart TD
    Start[User Input] --> Normalize[Normalize Input]
    Normalize --> Collect[Collect Candidates]
    
    Collect --> L0{AI Triage}
    L0 -->|Match| Add1[Add Candidate]
    L0 -->|No Match| L1{Explicit Override}
    
    L1 -->|Match| Add2[Add Candidate]
    L1 -->|No Match| L2{Scenario Match}
    
    L2 -->|Match| Add3[Add Candidate]
    L2 -->|No Match| L3{Semantic Match}
    
    L3 -->|Match| Add4[Add Candidate]
    L3 -->|No Match| L4{Fuzzy Fallback}
    
    L4 -->|Match| Add5[Add Candidate]
    L4 -->|No Match| NoMatch[No Match Result]
    
    Add1 --> Select[Candidate Selector]
    Add2 --> Select
    Add3 --> Select
    Add4 --> Select
    Add5 --> Select
    
    Select --> Decision{Decision Type}
    
    Decision -->|Auto Select| Single[Execute Single]
    Decision -->|User Choice| Choice[Present Options]
    Decision -->|Parallel| Parallel[Parallel Executor]
    Decision -->|No Candidates| NoMatch
    
    Single --> Result1[Return Result]
    Choice --> Result2[Wait for User]
    Parallel --> Aggregate[Aggregate Results]
    Aggregate --> Result3[Return Merged]
```

---

## Preference Learning

```mermaid
graph LR
    subgraph "Dimensions"
        C[Consistency 40%]
        S[Satisfaction 30%]
        CX[Context 20%]
        R[Recency 10%]
    end
    
    subgraph "Data Sources"
        H1[Selection History]
        H2[Satisfaction Ratings]
        H3[File Types]
        H4[Timestamps]
    end
    
    H1 --> C
    H2 --> S
    H3 --> CX
    H4 --> R
    
    C --> Combine[Combine Scores]
    S --> Combine
    CX --> Combine
    R --> Combine
    
    Combine --> Boost[Preference Boost]
    Boost --> Route[Routing Decision]
```

---

## Parallel Execution

```mermaid
sequenceDiagram
    participant User
    participant Router
    participant Selector
    participant Executor
    participant S1 as Skill 1
    participant S2 as Skill 2
    
    User->>Router: route("request")
    Router->>Selector: select(candidates)
    
    alt Confidence Gap > Threshold
        Selector-->>Router: auto_select
    else Confidence Gap Small
        Selector-->>Router: parallel_execute
    end
    
    Router->>Executor: execute(candidates)
    
    par Execute in Parallel
        Executor->>S1: execute
        Executor->>S2: execute
    end
    
    S1-->>Executor: result1
    S2-->>Executor: result2
    
    Executor->>Executor: aggregate(results)
    Executor-->>Router: merged_result
    Router-->>User: display(results)
```

---

## Configuration Flow

```mermaid
graph TD
    subgraph "Portable Core"
        PCORE[core/]
        PREG[registry.yaml]
        PPOL[policies/]
    end
    
    subgraph "Platform Adapter"
        ADPT[Target Adapter]
        TCONF[platform config]
    end
    
    subgraph "Project Overlay"
        OVL[.vibe/overlay.yaml]
    end
    
    subgraph "Generated Config"
        GEN[~/.claude/...]
    end
    
    PCORE --> ADPT
    TCONF --> ADPT
    OVL --> ADPT
    ADPT --> GEN
    
    GEN --> AGENT[Claude Code Agent]
```

---

## Cache Strategy

```mermaid
graph LR
    subgraph "L1: Memory Cache"
        M1[Hash: 500 entries]
    end
    
    subgraph "L2: File Cache"
        F1[YAML files]
    end
    
    subgraph "L3: Optional Redis"
        R1[Redis server]
    end
    
    Request[Routing Request] --> M1
    M1 -->|Hit| Result[Return Result]
    M1 -->|Miss| F1
    F1 -->|Hit| M1
    F1 -->|Miss| LLM[Call LLM]
    F1 -->|Hit| Result
    LLM --> M1
    LLM --> F1
```

---

## Module Dependencies

```mermaid
graph TD
    SR[SkillRouter] --> SM[SemanticMatcher]
    SR --> AIL[AI Triage Layer]
    SR --> CS[CandidateSelector]
    SR --> PE[ParallelExecutor]
    
    CS --> PA[PreferenceAnalyzer]
    CS --> Defaults[Defaults]
    
    PA --> PM[PreferenceManager]
    PA --> PL[PreferenceLearner]
    
    PE --> Defaults
    PE --> Cache[CacheManager]
    
    AIL --> LLM[LLMClient]
    AIL --> Cache
    
    Cache --> Defaults
```

---

## Platform Support Matrix

| Platform | Status | Notes |
|----------|--------|-------|
| Claude Code | ✅ Full | All features supported |
| OpenCode | ✅ Full | All features supported |
| Cursor | 🔄 Planned | Adapter needed |
| VS Code | 🔄 Planned | Extension needed |

---

## Performance Characteristics

| Operation | Latency (p50) | Latency (p95) | Cache Hit |
|-----------|---------------|---------------|-----------|
| Route (cached) | 10ms | 20ms | 70% |
| Route (uncached) | 150ms | 300ms | - |
| Preference analyze | 5ms | 15ms | 90% |
| Parallel execute | 200ms | 500ms | - |
