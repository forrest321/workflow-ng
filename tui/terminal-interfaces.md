# Terminal User Interface Development for AI Workflows

## Charm Bracelet TUI Framework

### Core Libraries Overview
- **Bubble Tea**: Go framework based on The Elm Architecture for TUI applications
- **Bubbles**: Component toolkit with reusable UI elements (inputs, lists, tables)
- **Lip Gloss**: Stylesheet-driven styling and layout system for terminal applications

### Elm Architecture Pattern
```go
// Model represents the application state
type Model struct {
    agents     []Agent
    tasks      []Task
    selected   int
    viewport   viewport.Model
    loading    bool
}

// Messages represent events that can update the model
type Msg interface{}

// Init returns initial commands for the application
func (m Model) Init() tea.Cmd {
    return tea.Batch(
        fetchAgentsCmd(),
        fetchTasksCmd(),
    )
}

// Update handles incoming events and updates the model
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        switch msg.String() {
        case "q", "ctrl+c":
            return m, tea.Quit
        case "up", "k":
            if m.selected > 0 {
                m.selected--
            }
        case "down", "j":
            if m.selected < len(m.agents)-1 {
                m.selected++
            }
        }
    case AgentsLoadedMsg:
        m.agents = msg.Agents
        m.loading = false
    }
    return m, nil
}

// View renders the UI based on the current model state
func (m Model) View() string {
    if m.loading {
        return "Loading agents..."
    }
    return m.renderAgentList()
}
```

## AI Agent Coordination Dashboard

### Real-Time Agent Monitoring Interface
```go
package main

import (
    "fmt"
    "time"
    
    "github.com/charmbracelet/bubbles/table"
    "github.com/charmbracelet/bubbles/viewport"
    tea "github.com/charmbracelet/bubbletea"
    "github.com/charmbracelet/lipgloss"
)

type AgentDashboard struct {
    agentTable    table.Model
    taskViewport  viewport.Model
    logViewport   viewport.Model
    selectedTab   int
    agents        []AgentStatus
    tasks         []TaskStatus
    logs          []LogEntry
}

type AgentStatus struct {
    ID           string
    Status       string
    CurrentTask  string
    Uptime       time.Duration
    TasksCompleted int
}

func NewAgentDashboard() *AgentDashboard {
    // Initialize table columns
    columns := []table.Column{
        {Title: "Agent ID", Width: 12},
        {Title: "Status", Width: 10},
        {Title: "Current Task", Width: 20},
        {Title: "Uptime", Width: 10},
        {Title: "Completed", Width: 10},
    }

    agentTable := table.New(
        table.WithColumns(columns),
        table.WithFocused(true),
        table.WithHeight(10),
    )

    taskViewport := viewport.New(40, 10)
    logViewport := viewport.New(40, 10)

    return &AgentDashboard{
        agentTable:   agentTable,
        taskViewport: taskViewport,
        logViewport:  logViewport,
        selectedTab:  0,
    }
}

func (d *AgentDashboard) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    var cmd tea.Cmd
    var cmds []tea.Cmd

    switch msg := msg.(type) {
    case tea.KeyMsg:
        switch msg.String() {
        case "tab":
            d.selectedTab = (d.selectedTab + 1) % 3
        case "q", "ctrl+c":
            return d, tea.Quit
        case "r":
            // Refresh data
            return d, tea.Batch(
                fetchAgentsCmd(),
                fetchTasksCmd(),
                fetchLogsCmd(),
            )
        }

    case AgentUpdateMsg:
        d.updateAgentTable(msg.Agents)
    case TaskUpdateMsg:
        d.updateTaskView(msg.Tasks)
    case LogUpdateMsg:
        d.updateLogView(msg.Logs)
    }

    // Update active component
    switch d.selectedTab {
    case 0:
        d.agentTable, cmd = d.agentTable.Update(msg)
    case 1:
        d.taskViewport, cmd = d.taskViewport.Update(msg)
    case 2:
        d.logViewport, cmd = d.logViewport.Update(msg)
    }
    
    cmds = append(cmds, cmd)
    return d, tea.Batch(cmds...)
}

func (d *AgentDashboard) View() string {
    var content string
    
    // Tab headers
    tabStyle := lipgloss.NewStyle().Padding(0, 2).Background(lipgloss.Color("240"))
    activeTabStyle := lipgloss.NewStyle().Padding(0, 2).Background(lipgloss.Color("36"))
    
    tabs := []string{"Agents", "Tasks", "Logs"}
    var renderedTabs []string
    
    for i, tab := range tabs {
        if i == d.selectedTab {
            renderedTabs = append(renderedTabs, activeTabStyle.Render(tab))
        } else {
            renderedTabs = append(renderedTabs, tabStyle.Render(tab))
        }
    }
    
    header := lipgloss.JoinHorizontal(lipgloss.Top, renderedTabs...)
    
    // Content based on selected tab
    switch d.selectedTab {
    case 0:
        content = d.agentTable.View()
    case 1:
        content = d.taskViewport.View()
    case 2:
        content = d.logViewport.View()
    }
    
    // Footer with controls
    footer := lipgloss.NewStyle().
        Foreground(lipgloss.Color("241")).
        Render("Tab: switch • r: refresh • q: quit")
    
    return lipgloss.JoinVertical(
        lipgloss.Left,
        header,
        content,
        footer,
    )
}
```

### Task Management Interface
```go
type TaskManager struct {
    taskList     list.Model
    taskDetails  viewport.Model
    actionPanel  viewport.Model
    tasks        []Task
    selectedTask *Task
    mode         string // "list", "details", "action"
}

type Task struct {
    ID          string
    Type        string
    Status      string
    AssignedTo  string
    Priority    int
    Created     time.Time
    Updated     time.Time
    Description string
    Progress    float64
}

func (tm *TaskManager) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        switch tm.mode {
        case "list":
            switch msg.String() {
            case "enter":
                // View task details
                if selected := tm.taskList.SelectedItem(); selected != nil {
                    task := selected.(TaskItem).Task
                    tm.selectedTask = &task
                    tm.mode = "details"
                    tm.taskDetails.SetContent(tm.formatTaskDetails(task))
                }
            case "n":
                // Create new task
                return tm, newTaskCmd()
            case "d":
                // Delete selected task
                if selected := tm.taskList.SelectedItem(); selected != nil {
                    task := selected.(TaskItem).Task
                    return tm, deleteTaskCmd(task.ID)
                }
            }
            
        case "details":
            switch msg.String() {
            case "esc":
                tm.mode = "list"
            case "e":
                tm.mode = "action"
                tm.actionPanel.SetContent(tm.formatActionPanel())
            case "a":
                // Assign task to agent
                return tm, assignTaskCmd(tm.selectedTask.ID)
            }
            
        case "action":
            switch msg.String() {
            case "esc":
                tm.mode = "details"
            case "enter":
                // Execute selected action
                return tm, tm.executeAction()
            }
        }
    }
    
    // Update active component
    var cmd tea.Cmd
    switch tm.mode {
    case "list":
        tm.taskList, cmd = tm.taskList.Update(msg)
    case "details":
        tm.taskDetails, cmd = tm.taskDetails.Update(msg)
    case "action":
        tm.actionPanel, cmd = tm.actionPanel.Update(msg)
    }
    
    return tm, cmd
}
```

## Interactive Command Interface

### CLI Command Builder
```go
type CommandBuilder struct {
    prompt       textinput.Model
    suggestions  []string
    selected     int
    history      []string
    mode         string // "input", "suggestions", "history"
}

func NewCommandBuilder() *CommandBuilder {
    prompt := textinput.New()
    prompt.Placeholder = "Enter command..."
    prompt.Focus()
    
    return &CommandBuilder{
        prompt:      prompt,
        suggestions: loadCommandSuggestions(),
        history:     loadCommandHistory(),
        mode:        "input",
    }
}

func (cb *CommandBuilder) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        switch cb.mode {
        case "input":
            switch msg.String() {
            case "tab":
                // Show suggestions
                cb.mode = "suggestions"
                cb.updateSuggestions(cb.prompt.Value())
            case "up":
                // Show history
                cb.mode = "history"
            case "enter":
                // Execute command
                command := cb.prompt.Value()
                cb.addToHistory(command)
                return cb, executeCommandCmd(command)
            }
            
        case "suggestions":
            switch msg.String() {
            case "esc":
                cb.mode = "input"
            case "enter":
                // Use selected suggestion
                if cb.selected < len(cb.suggestions) {
                    cb.prompt.SetValue(cb.suggestions[cb.selected])
                    cb.mode = "input"
                }
            case "up":
                if cb.selected > 0 {
                    cb.selected--
                }
            case "down":
                if cb.selected < len(cb.suggestions)-1 {
                    cb.selected++
                }
            }
            
        case "history":
            switch msg.String() {
            case "esc":
                cb.mode = "input"
            case "enter":
                // Use selected history item
                if cb.selected < len(cb.history) {
                    cb.prompt.SetValue(cb.history[cb.selected])
                    cb.mode = "input"
                }
            case "up":
                if cb.selected > 0 {
                    cb.selected--
                }
            case "down":
                if cb.selected < len(cb.history)-1 {
                    cb.selected++
                }
            }
        }
    }
    
    var cmd tea.Cmd
    cb.prompt, cmd = cb.prompt.Update(msg)
    return cb, cmd
}

func (cb *CommandBuilder) View() string {
    var content strings.Builder
    
    // Command prompt
    content.WriteString("Command: ")
    content.WriteString(cb.prompt.View())
    content.WriteString("\n\n")
    
    // Mode-specific content
    switch cb.mode {
    case "suggestions":
        content.WriteString("Suggestions:\n")
        for i, suggestion := range cb.suggestions {
            if i == cb.selected {
                content.WriteString("> " + suggestion + "\n")
            } else {
                content.WriteString("  " + suggestion + "\n")
            }
        }
        
    case "history":
        content.WriteString("History:\n")
        for i, item := range cb.history {
            if i == cb.selected {
                content.WriteString("> " + item + "\n")
            } else {
                content.WriteString("  " + item + "\n")
            }
        }
    }
    
    // Help text
    helpStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("241"))
    help := "Tab: suggestions • ↑: history • Enter: execute • Esc: cancel"
    content.WriteString("\n" + helpStyle.Render(help))
    
    return content.String()
}
```

## System Status Visualization

### Real-Time Metrics Display
```go
type MetricsDisplay struct {
    cpuGauge     progress.Model
    memoryGauge  progress.Model
    taskChart    sparkline.Model
    agentList    list.Model
    updateTicker time.Ticker
}

func (md *MetricsDisplay) View() string {
    // Main layout with Lip Gloss
    titleStyle := lipgloss.NewStyle().
        Bold(true).
        Foreground(lipgloss.Color("36")).
        Padding(1, 2)
    
    gaugeStyle := lipgloss.NewStyle().
        Border(lipgloss.RoundedBorder()).
        Padding(1).
        Width(30)
    
    chartStyle := lipgloss.NewStyle().
        Border(lipgloss.RoundedBorder()).
        Padding(1).
        Width(50).
        Height(10)
    
    // Header
    header := titleStyle.Render("AI Agent System Status")
    
    // System metrics
    cpuSection := gaugeStyle.Render(
        "CPU Usage\n" + md.cpuGauge.View(),
    )
    
    memorySection := gaugeStyle.Render(
        "Memory Usage\n" + md.memoryGauge.View(),
    )
    
    // Task throughput chart
    chartSection := chartStyle.Render(
        "Task Throughput (last 60s)\n" + md.taskChart.View(),
    )
    
    // Agent status
    agentSection := lipgloss.NewStyle().
        Border(lipgloss.RoundedBorder()).
        Padding(1).
        Width(40).
        Height(15).
        Render("Active Agents\n" + md.agentList.View())
    
    // Layout
    topRow := lipgloss.JoinHorizontal(
        lipgloss.Top,
        cpuSection,
        memorySection,
        chartSection,
    )
    
    bottomRow := lipgloss.JoinHorizontal(
        lipgloss.Top,
        agentSection,
        lipgloss.NewStyle().Width(10).Render(""), // Spacer
    )
    
    return lipgloss.JoinVertical(
        lipgloss.Left,
        header,
        topRow,
        bottomRow,
    )
}
```

## Configuration and Settings Interface

### Interactive Configuration Editor
```go
type ConfigEditor struct {
    sections    []ConfigSection
    selected    int
    editing     bool
    editor      textinput.Model
    currentKey  string
}

type ConfigSection struct {
    Name     string
    Settings []ConfigSetting
}

type ConfigSetting struct {
    Key         string
    Value       string
    Type        string // "string", "int", "bool", "select"
    Options     []string
    Description string
}

func (ce *ConfigEditor) View() string {
    var content strings.Builder
    
    // Title
    titleStyle := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("36"))
    content.WriteString(titleStyle.Render("Configuration Editor"))
    content.WriteString("\n\n")
    
    // Sections
    for i, section := range ce.sections {
        sectionStyle := lipgloss.NewStyle().Bold(true)
        if i == ce.selected && !ce.editing {
            sectionStyle = sectionStyle.Foreground(lipgloss.Color("214"))
        }
        
        content.WriteString(sectionStyle.Render(section.Name))
        content.WriteString("\n")
        
        // Settings in section
        for j, setting := range section.Settings {
            settingStyle := lipgloss.NewStyle().PaddingLeft(2)
            if ce.editing && ce.currentKey == setting.Key {
                settingStyle = settingStyle.Foreground(lipgloss.Color("36"))
                content.WriteString(settingStyle.Render(
                    fmt.Sprintf("%s: %s", setting.Key, ce.editor.View()),
                ))
            } else {
                content.WriteString(settingStyle.Render(
                    fmt.Sprintf("%s: %s", setting.Key, setting.Value),
                ))
            }
            content.WriteString("\n")
        }
        content.WriteString("\n")
    }
    
    // Help
    helpStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("241"))
    if ce.editing {
        content.WriteString(helpStyle.Render("Enter: save • Esc: cancel"))
    } else {
        content.WriteString(helpStyle.Render("Enter: edit • j/k: navigate • s: save config • q: quit"))
    }
    
    return content.String()
}
```

## Integration with AI Workflow Systems

### WebSocket Connection for Real-Time Updates
```go
func (app *TUIApp) connectWebSocket() tea.Cmd {
    return func() tea.Msg {
        conn, _, err := websocket.DefaultDialer.Dial("ws://coordinator:8080/ws", nil)
        if err != nil {
            return ConnectionErrorMsg{Error: err}
        }
        
        go func() {
            for {
                var update WorkflowUpdate
                err := conn.ReadJSON(&update)
                if err != nil {
                    app.program.Send(ConnectionErrorMsg{Error: err})
                    return
                }
                app.program.Send(WorkflowUpdateMsg{Update: update})
            }
        }()
        
        return ConnectionEstablishedMsg{Conn: conn}
    }
}
```

### Plugin System for Extensible Interfaces
```go
type TUIPlugin interface {
    Name() string
    Init() tea.Cmd
    Update(tea.Msg) (tea.Model, tea.Cmd)
    View() string
    Keybindings() []key.Binding
}

type PluginManager struct {
    plugins       map[string]TUIPlugin
    activePlugin  string
    pluginTabs    []string
}

func (pm *PluginManager) RegisterPlugin(plugin TUIPlugin) {
    pm.plugins[plugin.Name()] = plugin
    pm.pluginTabs = append(pm.pluginTabs, plugin.Name())
}

func (pm *PluginManager) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    if plugin := pm.plugins[pm.activePlugin]; plugin != nil {
        return plugin.Update(msg)
    }
    return pm, nil
}
```