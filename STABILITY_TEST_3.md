# 응답 안정화 검증 - 3단계 (최대 부하 테스트)

## 개요
이 테스트는 모델이 최대 컨텍스트를 유지하면서 복잡한 로직과 긴 텍스트를 동시에 처리할 때의 안정성을 검증합니다.

## 1. 대규모 데이터 처리 시뮬레이션 (SQL)
```sql
-- Create a complex table structure
CREATE TABLE user_activity_logs (
    log_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    activity_type VARCHAR(50) NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    details JSONB,
    ip_address INET,
    is_suspicious BOOLEAN DEFAULT FALSE,
    CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Index optimization for performance analysis
CREATE INDEX idx_user_activity_timestamp ON user_activity_logs (user_id, timestamp DESC);
CREATE INDEX idx_activity_type ON user_activity_logs (activity_type);

-- Complex analytical query with window functions
SELECT 
    u.username,
    l.activity_type,
    COUNT(*) OVER (PARTITION BY l.user_id) as total_activities,
    RANK() OVER (PARTITION BY l.activity_type ORDER BY l.timestamp DESC) as recent_rank,
    CASE 
        WHEN l.is_suspicious THEN 'High Risk'
        ELSE 'Normal'
    END as risk_level
FROM 
    user_activity_logs l
JOIN 
    users u ON l.user_id = u.id
WHERE 
    l.timestamp > NOW() - INTERVAL '30 days'
ORDER BY 
    l.timestamp DESC
LIMIT 100;
```

## 2. 복잡한 알고리즘 구현 (Rust)
```rust
use std::collections::HashMap;

/// A struct representing a directed graph
#[derive(Debug)]
struct Graph {
    adjacency_list: HashMap<u32, Vec<u32>>,
}

impl Graph {
    fn new() -> Self {
        Graph {
            adjacency_list: HashMap::new(),
        }
    }

    fn add_edge(&mut self, src: u32, dest: u32) {
        self.adjacency_list.entry(src).or_insert(Vec::new()).push(dest);
    }

    /// Performs a Breadth-First Search (BFS)
    fn bfs(&self, start_node: u32) -> Vec<u32> {
        let mut visited = Vec::new();
        let mut queue = std::collections::VecDeque::new();

        queue.push_back(start_node);
        visited.push(start_node);

        while let Some(node) = queue.pop_front() {
            if let Some(neighbors) = self.adjacency_list.get(&node) {
                for &neighbor in neighbors {
                    if !visited.contains(&neighbor) {
                        visited.push(neighbor);
                        queue.push_back(neighbor);
                    }
                }
            }
        }
        visited
    }
}

fn main() {
    let mut graph = Graph::new();
    graph.add_edge(1, 2);
    graph.add_edge(1, 3);
    graph.add_edge(2, 4);
    graph.add_edge(3, 5);
    
    println!("BFS Traversal: {:?}", graph.bfs(1));
}
```

## 3. 마크다운 테이블 렌더링 테스트
| ID | Name | Category | Status | Priority | Timestamp |
|:---:|:---|:---|:---:|:---:|---:|
| 101 | Server Config | DevOps | Active | High | 2026-02-11 00:18:00 |
| 102 | User Auth | Backend | Pending | Critical | 2026-02-11 00:18:05 |
| 103 | UI Layout | Frontend | Done | Low | 2026-02-11 00:17:55 |
| 104 | DB Migration | Database | Failed | High | 2026-02-11 00:16:30 |
| 105 | API Gateway | Network | Active | Medium | 2026-02-11 00:19:10 |

## 결론
모든 섹션이 정상적으로 생성되었습니다.
- [x] SQL 구문 강조 및 들여쓰기
- [x] Rust 코드 로직 및 구조체 정의
- [x] 마크다운 테이블 정렬 및 렌더링
