# AI-Powered Skill Routing - 技术实现细节

**版本**: 1.0
**日期**: 2026-03-29
**关联文档**: [完整架构设计](./ai-powered-skill-routing.md)

---

## 🔬 深入探讨关键实现细节

### 1. AI Triage Prompt Engineering

#### 1.1 提示词优化策略

**挑战**: 如何在有限的 token 内让 Haiku 准确理解意图？

**解决方案**: 分层提示词设计

```ruby
def build_triage_prompt(input, context, skill_registry)
  # 根据上下文复杂度动态调整提示词
  if complex_context?(context)
    build_detailed_prompt(input, context, skill_registry)
  else
    build_simple_prompt(input, context, skill_registry)
  end
end

def build_simple_prompt(input, context, skill_registry)
  # 简化版：适用于常见场景
  skills_list = skill_registry['skills']
    .select { |s| s['priority'] == 'P0' }  # 只包含高优先级技能
    .map { |s| "- #{s['id']}: #{s['intent']}" }
    .join("\n")

  <<~PROMPT
    分析用户请求，选择最合适的技能：

    用户: #{input}

    可用技能:
    #{skills_list}

    返回JSON:
    {
      "skill": "技能ID",
      "confidence": 0.0-1.0
    }
  PROMPT
end

def build_detailed_prompt(input, context, skill_registry)
  # 详细版：适用于复杂场景
  # 包含上下文、历史、技能详情等
  # ...
end
```

#### 1.2 Few-Shot Learning

```ruby
def build_prompt_with_examples(input, context)
  examples = load_successful_examples(context)

  <<~PROMPT
    你是技能路由专家。参考以下成功案例：

    ## 成功案例
    #{format_examples(examples)}

    ## 当前请求
    #{format_current_request(input, context)}

    ## 任务
    参考案例，为当前请求选择最合适的技能。

    返回JSON:
    {
      "skill": "技能ID",
      "confidence": 0.0-1.0,
      "reasoning": "选择原因（参考案例X）",
      "similar_case": "最相似的案例ID"
    }
  PROMPT
end
```

---

### 2. 智能缓存策略

#### 2.1 多级缓存架构

```ruby
class MultiLevelCache
  def initialize
    @l1_cache = {}  # Memory cache (fast, small)
    @l2_cache = FileCache.new  # File cache (slower, larger)
    @l3_cache = RedisCache.new if ENV['REDIS_URL']  # Optional Redis
  end

  def get(key)
    # L1: Memory cache (current session)
    if @l1_cache[key]
      record_hit(:l1)
      return @l1_cache[key]
    end

    # L2: File cache (persistent)
    if @l2_cache.key?(key)
      value = @l2_cache.get(key)
      @l1_cache[key] = value  # Promote to L1
      record_hit(:l2)
      return value
    end

    # L3: Redis cache (distributed, optional)
    if @l3_cache && @l3_cache.exists?(key)
      value = @l3_cache.get(key)
      @l1_cache[key] = value  # Promote to L1
      @l2_cache.set(key, value)  # Backup to L2
      record_hit(:l3)
      return value
    end

    record_miss
    nil
  end

  def set(key, value, ttl:)
    @l1_cache[key] = value
    @l2_cache.set(key, value, ttl: ttl)
    @l3_cache&.set(key, value, ttl: ttl)
  end

  def cache_stats
    {
      l1_size: @l1_cache.size,
      l2_size: @l2_cache.size,
      l1_hits: @hits[:l1],
      l2_hits: @hits[:l2],
      l3_hits: @hits[:l3],
      misses: @misses,
      hit_rate: calculate_hit_rate
    }
  end
end
```

#### 2.2 智能缓存键生成

```ruby
def generate_cache_key(input, context)
  # 策略1: 简化输入（去除常见变化）
  normalized_input = normalize_for_cache(input)

  # 策略2: 只包含关键上下文
  relevant_context = extract_relevant_context(context)

  # 策略3: 生成哈希
  base = "#{normalized_input}:#{relevant_context.sort.to_h}"
  Digest::SHA256.hexdigest(base)[0..16]
end

def normalize_for_cache(input)
  # 去除不影响路由的因素
  input
    .gsub(/\d+/, 'N')           # 数字替换
    .gsub(/['"].*?['"]/, 'X')   # 引号内容替换
    .gsub(/\s+/, ' ')           # 标准化空白
    .strip
    .downcase
end

def extract_relevant_context(context)
  # 只保留影响路由的上下文
  {
    file_type: context[:file_type],
    has_errors: context[:error_count]&.positive?
    # 忽略：recent_files, current_task 等
  }
end
```

#### 2.3 缓存预热策略

```ruby
class CacheWarmup
  def initialize(router, cache)
    @router = router
    @cache = cache
  end

  def warmup_common_patterns
    # 常见模式列表
    common_patterns = [
      { input: "帮我调试", context: {} },
      { input: "审查代码", context: {} },
      { input: "重构", context: {} },
      # ... 更多模式
    ]

    # 批量预热（后台执行）
    warmup_async(common_patterns)
  end

  def warmup_from_history(days: 7)
    # 从历史记录中提取常见请求
    history = load_recent_history(days)

    # 找出高频模式
    frequent_patterns = history
      .group_by { |h| normalize_input(h[:input]) }
      .select { |_, v| v.size >= 3 }  # 至少出现3次
      .keys

    # 预热这些模式
    warmup_async(frequent_patterns.map { |input| { input: input, context: {} } })
  end

  private

  def warmup_async(patterns)
    patterns.each do |pattern|
      Thread.new do
        @router.route(pattern[:input], pattern[:context])
      end
    end
  end
end
```

---

### 3. 成本优化技术

#### 3.1 Token 优化

```ruby
class TokenOptimizer
  def optimize_prompt(prompt)
    # 策略1: 移除冗余信息
    prompt = remove_redundancy(prompt)

    # 策略2: 压缩技能描述
    prompt = compress_skill_descriptions(prompt)

    # 策略3: 使用缩写
    prompt = use_abbreviations(prompt)

    prompt
  end

  private

  def remove_redundancy(prompt)
    # 移除重复的示例
    prompt = remove_duplicate_examples(prompt)

    # 移除不必要的修饰词
    prompt = remove_fillers(prompt)

    prompt
  end

  def compress_skill_descriptions(prompt)
    # 使用短描述代替长描述
    # 例如："Systematic debugging with root cause analysis" → "Debug: find root cause"
    prompt.gsub(/#{skill['description']}/, skill['short_desc'])
  end

  def use_abbreviations(prompt)
    # 定义常用缩写
    abbreviations = {
      'investigation' => 'inv',
      'development' => 'dev',
      'application' => 'app'
      # ...
    }

    abbreviations.each do |full, abbr|
      prompt = prompt.gsub(/\b#{full}\b/, abbr)
    end

    prompt
  end
end
```

#### 3.2 批量处理

```ruby
class BatchProcessor
  def initialize(llm_client, batch_size: 5)
    @llm_client = llm_client
    @batch_size = batch_size
  end

  def process_batch(inputs)
    # 将多个输入合并为一个请求
    combined_prompt = build_batch_prompt(inputs)

    # 单次 API 调用
    response = @llm_client.call(prompt: combined_prompt)

    # 解析批量响应
    parse_batch_response(response, inputs.size)
  end

  private

  def build_batch_prompt(inputs)
    numbered_list = inputs.map.with_index do |input, i|
      "#{i + 1}. #{input[:input]}"
    end.join("\n")

    <<~PROMPT
      批量分析以下 #{inputs.size} 个请求，为每个请求选择最合适的技能：

      #{numbered_list}

      返回JSON数组:
      [
        {"index": 1, "skill": "skill_id", "confidence": 0.8},
        {"index": 2, "skill": "skill_id", "confidence": 0.9},
        ...
      ]
    PROMPT
  end
end
```

---

### 4. 性能优化

#### 4.1 连接池

```ruby
class ConnectionPool
  def initialize(size:, timeout:, &block)
    @size = size
    @timeout = timeout
    @factory = block
    @pool = []
    @allocated = {}
    @mutex = Mutex.new
  end

  def with
    conn = acquire
    begin
      yield conn
    ensure
      release(conn)
    end
  end

  private

  def acquire
    @mutex.synchronize do
      # 尝试从池中获取
      conn = @pool.pop
      return conn if conn

      # 池为空，创建新连接
      if @allocated.size < @size
        conn = @factory.call
        @allocated[conn] = true
        return conn
      end

      # 等待连接释放
      wait_for_connection
    end
  end

  def release(conn)
    @mutex.synchronize do
      @pool << conn
    end
  end
end

# 使用示例
llm_pool = ConnectionPool.new(size: 5, timeout: 10) do
  Net::HTTP.new(API_HOST, API_PORT)
end

llm_pool.with do |connection|
  # 使用 connection 发送请求
end
```

#### 4.2 异步处理

```ruby
class AsyncTriage
  def initialize(router)
    @router = router
    @executor = Concurrent::ThreadPoolExecutor.new(
      min_threads: 2,
      max_threads: 5,
      max_queue: 100
    )
  end

  def route_async(input, context, &callback)
    # 异步执行路由
    future = Concurrent::Future.execute(executor: @executor) do
      @router.route(input, context)
    end

    # 完成后回调
    future.on_success! do |result|
      callback.call(result)
    end

    future
  end

  def route_batch(inputs)
    # 批量异步处理
    futures = inputs.map do |input|
      route_async(input[:input], input[:context]) do |result|
        # 处理结果
        store_result(input, result)
      end
    end

    # 等待所有完成
    futures.map(&:value!)
  end
end
```

---

### 5. 质量保证

#### 5.1 准确性评估

```ruby
class AccuracyEvaluator
  def evaluate(test_cases)
    results = test_cases.map do |test_case|
      actual = @router.route(test_case[:input], test_case[:context])
      expected = test_case[:expected_skill]

      {
        input: test_case[:input],
        expected: expected,
        actual: actual[:skill],
        correct: actual[:skill] == expected,
        confidence: actual[:confidence]
      }
    end

    calculate_metrics(results)
  end

  private

  def calculate_metrics(results)
    total = results.size
    correct = results.count { |r| r[:correct] }

    {
      total: total,
      correct: correct,
      accuracy: correct.to_f / total,
      high_confidence_correct: high_confidence_accuracy(results),
      low_confidence_correct: low_confidence_accuracy(results)
    }
  end

  def high_confidence_accuracy(results)
    high_conf = results.select { |r| r[:confidence] == :high }
    return nil if high_conf.empty?

    correct = high_conf.count { |r| r[:correct] }
    correct.to_f / high_conf.size
  end
end
```

#### 5.2 A/B 测试框架

```ruby
class ABTestFramework
  def initialize(variant_a, variant_b)
    @variant_a = variant_a
    @variant_b = variant_b
    @results = { a: [], b: [] }
    @user_assignments = {}
  end

  def route(user_id, input, context)
    variant = assign_variant(user_id)

    start_time = Time.now
    result = variant.call(input, context)
    duration = Time.now - start_time

    record_result(variant, user_id, result, duration)
    result
  end

  def report
    {
      variant_a: analyze_variant(@results[:a]),
      variant_b: analyze_variant(@results[:b]),
      winner: determine_winner,
      statistical_significance: calculate_significance
    }
  end

  private

  def assign_variant(user_id)
    # 一致性哈希：同一个用户总是分配到同一组
    @user_assignments[user_id] ||= begin
      hash = Digest::MD5.hexdigest(user_id).to_i(16)
      hash % 2 == 0 ? @variant_a : @variant_b
    end
  end

  def determine_winner
    metrics_a = analyze_variant(@results[:a])
    metrics_b = analyze_variant(@results[:b])

    # 比较准确率和响应时间
    if metrics_a[:accuracy] > metrics_b[:accuracy] &&
       metrics_a[:avg_duration] < metrics_b[:avg_duration]
      return :a
    elsif metrics_b[:accuracy] > metrics_a[:accuracy] &&
          metrics_b[:avg_duration] < metrics_a[:avg_duration]
      return :b
    end

    :inconclusive
  end

  def calculate_significance
    # 使用统计检验（如 t-test）判断显著性
    # ...
  end
end
```

---

### 6. 错误处理和恢复

#### 6.1 智能重试

```ruby
class IntelligentRetry
  def initialize(max_retries: 3, backoff_base: 2)
    @max_retries = max_retries
    @backoff_base = backoff_base
  end

  def with_retry
    retries = 0

    begin
      yield
    rescue RetryableError => e
      retries += 1

      if retries <= @max_retries
        # 指数退避
        delay = @backoff_base**retries
        sleep(delay)

        # 记录重试
        log_retry(e, retries, delay)

        retry
      else
        # 最终失败
        log_final_failure(e, retries)
        nil  # 触发回退机制
      end
    rescue NonRetryableError => e
      # 不可重试的错误，直接失败
      log_non_retryable_error(e)
      nil
    end
  end
end

# 使用示例
retry_manager = IntelligentRetry.new

result = retry_manager.with_retry do
  llm_client.call(prompt: prompt)
end
```

#### 6.2 熔断机制

```ruby
class CircuitBreaker
  def initialize(threshold: 5, timeout: 60)
    @threshold = threshold
    @timeout = timeout
    @failures = 0
    @last_failure_time = nil
    @state = :closed  # closed, open, half-open
  end

  def call
    return nil if @state == :open && circuit_open?

    begin
      result = yield
      on_success
      result
    rescue StandardError => e
      on_failure(e)
      nil
    end
  end

  private

  def on_failure(error)
    @failures += 1
    @last_failure_time = Time.now

    if @failures >= @threshold
      @state = :open
      log_circuit_open
    end
  end

  def on_success
    @failures = 0
    @state = :closed
  end

  def circuit_open?
    @state == :open &&
      Time.now - @last_failure_time < @timeout
  end
end
```

---

## 🎯 实施检查清单

### Phase 1: 基础设施 (3天)
- [ ] `AITriageLayer` 类实现
- [ ] `LLMClient` 类实现
- [ ] `CacheManager` 类实现
- [ ] 单元测试 >80% 覆盖
- [ ] 本地环境测试通过

### Phase 2: 集成和优化 (2天)
- [ ] 集成到 `SkillRouter`
- [ ] 多级缓存实现
- [ ] Token 优化
- [ ] 性能测试达标

### Phase 3: 可靠性保证 (2天)
- [ ] 回退机制
- [ ] 错误监控
- [ ] 熔断器
- [ ] 智能重试

### Phase 4: 质量验证 (2天)
- [ ] 准确性评估
- [ ] A/B 测试框架
- [ ] 压力测试
- [ ] 成本验证

### Phase 5: 灰度发布 (1周)
- [ ] Feature flag
- [ ] 10% 流量
- [ ] 监控指标
- [ ] 收集反馈

### Phase 6: 全量发布 (3天)
- [ ] 逐步提升流量
- [ ] 持续监控
- [ ] 文档更新
- [ ] 培训和推广

---

## 📊 成功指标

| 指标 | 目标 | 测量方式 |
|------|------|---------|
| 匹配准确率 | >90% | A/B 测试对比 |
| 缓存命中率 | >70% | 缓存监控 |
| 响应时间 P95 | <300ms | 性能监控 |
| 错误率 | <2% | 错误监控 |
| 月成本 | <$1 | 成本监控 |
| 用户满意度 | >80% | 用户反馈 |

---

## 🚀 快速开始

```bash
# 1. 设置环境变量
export ANTHROPIC_API_KEY=sk-ant-xxxxx
export VIBE_AI_TRIAGE_ENABLED=true

# 2. 运行测试
ruby test/skill_router/ai_triage_layer_test.rb

# 3. 本地体验
bin/vibe route "帮我调试这个生产环境的bug"

# 4. 查看统计
bin/vibe stats ai-triage
```

这个优化方案已经具备了完整的实施细节，可以立即开始开发！🎉
