# Web Frontend Integration for AI Workflow Systems

## Frontend Framework Architecture for AI Coordination

### React-Based Dashboard Architecture
```typescript
// Main Dashboard Component
import React, { useState, useEffect } from 'react';
import { useWebSocket } from './hooks/useWebSocket';
import { AgentGrid } from './components/AgentGrid';
import { TaskQueue } from './components/TaskQueue';
import { WorkflowVisualization } from './components/WorkflowVisualization';

interface DashboardState {
  agents: Agent[];
  tasks: Task[];
  workflows: Workflow[];
  systemMetrics: SystemMetrics;
}

export const AIDashboard: React.FC = () => {
  const [state, setState] = useState<DashboardState>({
    agents: [],
    tasks: [],
    workflows: [],
    systemMetrics: {} as SystemMetrics,
  });

  const { connected, send, lastMessage } = useWebSocket('ws://api/ws');

  useEffect(() => {
    if (lastMessage) {
      const update = JSON.parse(lastMessage.data);
      setState(prev => ({
        ...prev,
        [update.type]: update.data,
      }));
    }
  }, [lastMessage]);

  const handleTaskAssignment = (taskId: string, agentId: string) => {
    send(JSON.stringify({
      type: 'ASSIGN_TASK',
      payload: { taskId, agentId }
    }));
  };

  return (
    <div className="dashboard-container">
      <header className="dashboard-header">
        <h1>AI Workflow Coordination Dashboard</h1>
        <div className="connection-status">
          Status: {connected ? 'Connected' : 'Disconnected'}
        </div>
      </header>
      
      <div className="dashboard-grid">
        <AgentGrid 
          agents={state.agents}
          onAgentSelect={(agent) => console.log('Selected:', agent)}
        />
        <TaskQueue 
          tasks={state.tasks}
          onTaskAssign={handleTaskAssignment}
        />
        <WorkflowVisualization 
          workflows={state.workflows}
          metrics={state.systemMetrics}
        />
      </div>
    </div>
  );
};
```

### Vue.js Component Architecture
```vue
<template>
  <div class="ai-workflow-dashboard">
    <nav class="sidebar">
      <workflow-navigator 
        :workflows="workflows"
        @select="selectWorkflow"
      />
    </nav>
    
    <main class="main-content">
      <agent-coordination-panel
        :agents="agents"
        :selected-workflow="selectedWorkflow"
        @agent-action="handleAgentAction"
      />
      
      <task-management-panel
        :tasks="filteredTasks"
        @task-update="updateTask"
      />
    </main>
    
    <aside class="status-panel">
      <system-metrics :metrics="systemMetrics" />
      <real-time-logs :logs="recentLogs" />
    </aside>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useAIWorkflowStore } from '@/stores/aiWorkflow'
import { useWebSocketConnection } from '@/composables/useWebSocket'

const store = useAIWorkflowStore()
const { connect, send, isConnected } = useWebSocketConnection()

const selectedWorkflow = ref<Workflow | null>(null)

const agents = computed(() => store.agents)
const workflows = computed(() => store.workflows)
const systemMetrics = computed(() => store.systemMetrics)
const recentLogs = computed(() => store.logs.slice(-50))

const filteredTasks = computed(() => {
  if (!selectedWorkflow.value) return []
  return store.tasks.filter(task => 
    task.workflowId === selectedWorkflow.value?.id
  )
})

const selectWorkflow = (workflow: Workflow) => {
  selectedWorkflow.value = workflow
  store.loadWorkflowDetails(workflow.id)
}

const handleAgentAction = (action: AgentAction) => {
  send({
    type: 'AGENT_ACTION',
    payload: action
  })
}

const updateTask = (task: Task) => {
  store.updateTask(task)
}

onMounted(() => {
  connect('ws://localhost:8080/ws')
  store.initialize()
})
</script>
```

## API Integration Patterns

### RESTful API Client with Error Handling
```typescript
class AIWorkflowAPIClient {
  private baseURL: string;
  private authToken: string;

  constructor(baseURL: string, authToken: string) {
    this.baseURL = baseURL;
    this.authToken = authToken;
  }

  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<APIResponse<T>> {
    const url = `${this.baseURL}${endpoint}`;
    
    const defaultHeaders = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${this.authToken}`,
    };

    try {
      const response = await fetch(url, {
        ...options,
        headers: { ...defaultHeaders, ...options.headers },
      });

      if (!response.ok) {
        throw new APIError(
          response.status,
          await response.text(),
          response.statusText
        );
      }

      const data = await response.json();
      return { success: true, data };
    } catch (error) {
      console.error(`API request failed: ${endpoint}`, error);
      return { 
        success: false, 
        error: error instanceof APIError ? error : new APIError(500, 'Unknown error')
      };
    }
  }

  // Agent management
  async getAgents(): Promise<APIResponse<Agent[]>> {
    return this.request<Agent[]>('/api/v1/agents');
  }

  async createAgent(config: AgentConfig): Promise<APIResponse<Agent>> {
    return this.request<Agent>('/api/v1/agents', {
      method: 'POST',
      body: JSON.stringify(config),
    });
  }

  async updateAgentStatus(agentId: string, status: AgentStatus): Promise<APIResponse<void>> {
    return this.request<void>(`/api/v1/agents/${agentId}/status`, {
      method: 'PATCH',
      body: JSON.stringify({ status }),
    });
  }

  // Task management
  async getTasks(filters?: TaskFilters): Promise<APIResponse<Task[]>> {
    const queryParams = filters ? new URLSearchParams(filters as any).toString() : '';
    return this.request<Task[]>(`/api/v1/tasks${queryParams ? `?${queryParams}` : ''}`);
  }

  async assignTask(taskId: string, agentId: string): Promise<APIResponse<TaskAssignment>> {
    return this.request<TaskAssignment>(`/api/v1/tasks/${taskId}/assign`, {
      method: 'POST',
      body: JSON.stringify({ agentId }),
    });
  }

  // Workflow coordination
  async getWorkflows(): Promise<APIResponse<Workflow[]>> {
    return this.request<Workflow[]>('/api/v1/workflows');
  }

  async createWorkflow(definition: WorkflowDefinition): Promise<APIResponse<Workflow>> {
    return this.request<Workflow>('/api/v1/workflows', {
      method: 'POST',
      body: JSON.stringify(definition),
    });
  }

  async executeWorkflow(workflowId: string, params: WorkflowParams): Promise<APIResponse<WorkflowExecution>> {
    return this.request<WorkflowExecution>(`/api/v1/workflows/${workflowId}/execute`, {
      method: 'POST',
      body: JSON.stringify(params),
    });
  }
}
```

### GraphQL Integration for Complex Queries
```typescript
import { ApolloClient, InMemoryCache, gql, useQuery, useMutation } from '@apollo/client';

const GET_WORKFLOW_DETAILS = gql`
  query GetWorkflowDetails($workflowId: ID!) {
    workflow(id: $workflowId) {
      id
      name
      status
      createdAt
      updatedAt
      agents {
        id
        status
        currentTask {
          id
          type
          priority
          progress
        }
      }
      tasks {
        id
        type
        status
        assignedTo {
          id
          name
        }
        dependencies {
          id
          status
        }
        metadata
      }
      metrics {
        totalTasks
        completedTasks
        failedTasks
        averageExecutionTime
        throughputPerHour
      }
    }
  }
`;

const ASSIGN_TASK_MUTATION = gql`
  mutation AssignTask($taskId: ID!, $agentId: ID!) {
    assignTask(taskId: $taskId, agentId: $agentId) {
      id
      status
      assignedAt
      agent {
        id
        name
      }
    }
  }
`;

export const WorkflowDetailsView: React.FC<{ workflowId: string }> = ({ workflowId }) => {
  const { data, loading, error, refetch } = useQuery(GET_WORKFLOW_DETAILS, {
    variables: { workflowId },
    pollInterval: 5000, // Poll every 5 seconds for real-time updates
  });

  const [assignTask] = useMutation(ASSIGN_TASK_MUTATION, {
    onCompleted: () => refetch(),
    onError: (error) => console.error('Assignment failed:', error),
  });

  if (loading) return <LoadingSpinner />;
  if (error) return <ErrorDisplay error={error} />;

  const workflow = data?.workflow;

  return (
    <div className="workflow-details">
      <WorkflowHeader workflow={workflow} />
      <div className="workflow-content">
        <AgentPanel 
          agents={workflow.agents}
          onTaskAssign={(taskId, agentId) => 
            assignTask({ variables: { taskId, agentId } })
          }
        />
        <TaskPanel tasks={workflow.tasks} />
        <MetricsPanel metrics={workflow.metrics} />
      </div>
    </div>
  );
};
```

## Real-Time Data Synchronization

### WebSocket Integration with State Management
```typescript
// Redux store slice for real-time updates
import { createSlice, PayloadAction } from '@reduxjs/toolkit';

interface RealtimeState {
  connected: boolean;
  lastUpdate: string;
  agents: Agent[];
  tasks: Task[];
  systemMetrics: SystemMetrics;
  notifications: Notification[];
}

const realtimeSlice = createSlice({
  name: 'realtime',
  initialState: {
    connected: false,
    lastUpdate: '',
    agents: [],
    tasks: [],
    systemMetrics: {} as SystemMetrics,
    notifications: [],
  } as RealtimeState,
  reducers: {
    connectionEstablished: (state) => {
      state.connected = true;
    },
    connectionLost: (state) => {
      state.connected = false;
    },
    agentUpdated: (state, action: PayloadAction<Agent>) => {
      const index = state.agents.findIndex(a => a.id === action.payload.id);
      if (index >= 0) {
        state.agents[index] = action.payload;
      } else {
        state.agents.push(action.payload);
      }
      state.lastUpdate = new Date().toISOString();
    },
    taskUpdated: (state, action: PayloadAction<Task>) => {
      const index = state.tasks.findIndex(t => t.id === action.payload.id);
      if (index >= 0) {
        state.tasks[index] = action.payload;
      } else {
        state.tasks.push(action.payload);
      }
      state.lastUpdate = new Date().toISOString();
    },
    metricsUpdated: (state, action: PayloadAction<SystemMetrics>) => {
      state.systemMetrics = action.payload;
      state.lastUpdate = new Date().toISOString();
    },
    notificationReceived: (state, action: PayloadAction<Notification>) => {
      state.notifications.unshift(action.payload);
      if (state.notifications.length > 100) {
        state.notifications = state.notifications.slice(0, 100);
      }
    },
  },
});

// WebSocket middleware
export const createWebSocketMiddleware = (url: string) => {
  return (store: any) => (next: any) => {
    let socket: WebSocket | null = null;

    const connect = () => {
      socket = new WebSocket(url);
      
      socket.onopen = () => {
        store.dispatch(realtimeSlice.actions.connectionEstablished());
      };
      
      socket.onclose = () => {
        store.dispatch(realtimeSlice.actions.connectionLost());
        // Reconnect after 5 seconds
        setTimeout(connect, 5000);
      };
      
      socket.onmessage = (event) => {
        const message = JSON.parse(event.data);
        
        switch (message.type) {
          case 'AGENT_UPDATE':
            store.dispatch(realtimeSlice.actions.agentUpdated(message.data));
            break;
          case 'TASK_UPDATE':
            store.dispatch(realtimeSlice.actions.taskUpdated(message.data));
            break;
          case 'METRICS_UPDATE':
            store.dispatch(realtimeSlice.actions.metricsUpdated(message.data));
            break;
          case 'NOTIFICATION':
            store.dispatch(realtimeSlice.actions.notificationReceived(message.data));
            break;
        }
      };
    };

    connect();

    return (action: any) => {
      // Send actions to server if needed
      if (action.type.startsWith('server/')) {
        socket?.send(JSON.stringify(action));
      }
      return next(action);
    };
  };
};
```

## Interactive Workflow Visualization

### D3.js Integration for Workflow Graphs
```typescript
import * as d3 from 'd3';
import { useRef, useEffect } from 'react';

interface WorkflowNode {
  id: string;
  type: 'agent' | 'task' | 'decision';
  label: string;
  status: 'pending' | 'running' | 'completed' | 'failed';
  x?: number;
  y?: number;
}

interface WorkflowLink {
  source: string;
  target: string;
  type: 'dependency' | 'assignment' | 'completion';
}

export const WorkflowGraph: React.FC<{
  nodes: WorkflowNode[];
  links: WorkflowLink[];
  onNodeClick: (node: WorkflowNode) => void;
}> = ({ nodes, links, onNodeClick }) => {
  const svgRef = useRef<SVGSVGElement>(null);

  useEffect(() => {
    if (!svgRef.current) return;

    const svg = d3.select(svgRef.current);
    svg.selectAll('*').remove(); // Clear previous render

    const width = 800;
    const height = 600;

    // Create force simulation
    const simulation = d3.forceSimulation(nodes)
      .force('link', d3.forceLink(links).id((d: any) => d.id).distance(100))
      .force('charge', d3.forceManyBody().strength(-300))
      .force('center', d3.forceCenter(width / 2, height / 2));

    // Create links
    const link = svg.append('g')
      .selectAll('line')
      .data(links)
      .enter().append('line')
      .attr('class', (d) => `link link-${d.type}`)
      .attr('stroke', '#999')
      .attr('stroke-opacity', 0.6)
      .attr('stroke-width', 2);

    // Create nodes
    const node = svg.append('g')
      .selectAll('g')
      .data(nodes)
      .enter().append('g')
      .attr('class', 'node')
      .call(d3.drag()
        .on('start', dragstarted)
        .on('drag', dragged)
        .on('end', dragended));

    // Add circles for nodes
    node.append('circle')
      .attr('r', (d) => d.type === 'agent' ? 15 : 10)
      .attr('fill', (d) => getNodeColor(d.type, d.status))
      .attr('stroke', '#fff')
      .attr('stroke-width', 2);

    // Add labels
    node.append('text')
      .text((d) => d.label)
      .attr('x', 20)
      .attr('y', 5)
      .attr('font-size', '12px')
      .attr('font-family', 'Arial, sans-serif');

    // Add click handler
    node.on('click', (event, d) => {
      onNodeClick(d);
    });

    // Update positions on simulation tick
    simulation.on('tick', () => {
      link
        .attr('x1', (d: any) => d.source.x)
        .attr('y1', (d: any) => d.source.y)
        .attr('x2', (d: any) => d.target.x)
        .attr('y2', (d: any) => d.target.y);

      node
        .attr('transform', (d: any) => `translate(${d.x},${d.y})`);
    });

    function dragstarted(event: any, d: any) {
      if (!event.active) simulation.alphaTarget(0.3).restart();
      d.fx = d.x;
      d.fy = d.y;
    }

    function dragged(event: any, d: any) {
      d.fx = event.x;
      d.fy = event.y;
    }

    function dragended(event: any, d: any) {
      if (!event.active) simulation.alphaTarget(0);
      d.fx = null;
      d.fy = null;
    }

    function getNodeColor(type: string, status: string): string {
      const colors = {
        agent: { pending: '#ffa500', running: '#00ff00', completed: '#0000ff', failed: '#ff0000' },
        task: { pending: '#ffff00', running: '#00ffff', completed: '#008000', failed: '#800000' },
        decision: { pending: '#ff00ff', running: '#800080', completed: '#008080', failed: '#400040' }
      };
      return colors[type as keyof typeof colors]?.[status as keyof typeof colors.agent] || '#ccc';
    }

  }, [nodes, links, onNodeClick]);

  return (
    <div className="workflow-graph">
      <svg ref={svgRef} width={800} height={600} />
    </div>
  );
};
```

## Performance Optimization

### Virtual Scrolling for Large Datasets
```typescript
import { FixedSizeList as List } from 'react-window';

interface VirtualizedTaskListProps {
  tasks: Task[];
  onTaskSelect: (task: Task) => void;
}

const TaskRow: React.FC<{
  index: number;
  style: React.CSSProperties;
  data: { tasks: Task[]; onSelect: (task: Task) => void };
}> = ({ index, style, data }) => {
  const task = data.tasks[index];
  
  return (
    <div style={style} className="task-row" onClick={() => data.onSelect(task)}>
      <div className="task-id">{task.id}</div>
      <div className="task-type">{task.type}</div>
      <div className="task-status">{task.status}</div>
      <div className="task-progress">
        <div 
          className="progress-bar"
          style={{ width: `${task.progress}%` }}
        />
      </div>
    </div>
  );
};

export const VirtualizedTaskList: React.FC<VirtualizedTaskListProps> = ({
  tasks,
  onTaskSelect
}) => {
  return (
    <List
      height={400}
      itemCount={tasks.length}
      itemSize={60}
      itemData={{ tasks, onSelect: onTaskSelect }}
    >
      {TaskRow}
    </List>
  );
};
```

### Code Splitting and Lazy Loading
```typescript
import { lazy, Suspense } from 'react';
import { Routes, Route } from 'react-router-dom';

// Lazy load components
const Dashboard = lazy(() => import('./pages/Dashboard'));
const WorkflowEditor = lazy(() => import('./pages/WorkflowEditor'));
const AgentManager = lazy(() => import('./pages/AgentManager'));
const SystemMonitoring = lazy(() => import('./pages/SystemMonitoring'));

export const AppRoutes: React.FC = () => {
  return (
    <Suspense fallback={<div>Loading...</div>}>
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/workflows" element={<WorkflowEditor />} />
        <Route path="/agents" element={<AgentManager />} />
        <Route path="/monitoring" element={<SystemMonitoring />} />
      </Routes>
    </Suspense>
  );
};
```

## Progressive Web App Features

### Service Worker for Offline Support
```typescript
// service-worker.ts
const CACHE_NAME = 'ai-workflow-v1';
const urlsToCache = [
  '/',
  '/static/js/bundle.js',
  '/static/css/main.css',
  '/manifest.json'
];

self.addEventListener('install', (event: any) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(urlsToCache))
  );
});

self.addEventListener('fetch', (event: any) => {
  event.respondWith(
    caches.match(event.request)
      .then((response) => {
        // Return cached version or fetch from network
        return response || fetch(event.request);
      })
  );
});

// Background sync for offline actions
self.addEventListener('sync', (event: any) => {
  if (event.tag === 'background-sync-actions') {
    event.waitUntil(syncPendingActions());
  }
});

async function syncPendingActions() {
  const pendingActions = await getStoredActions();
  for (const action of pendingActions) {
    try {
      await fetch('/api/v1/actions', {
        method: 'POST',
        body: JSON.stringify(action),
        headers: { 'Content-Type': 'application/json' }
      });
      await removeStoredAction(action.id);
    } catch (error) {
      console.error('Failed to sync action:', error);
    }
  }
}
```