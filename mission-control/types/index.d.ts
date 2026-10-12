/** A usage sample (mirrors hooks/forecast.ts). */
export type Sample = { at: number; costUsd: number; fiveHour?: number; sevenDay?: number }

/** What an agent reported through the step tool (mirrors hooks/progress.ts). */
export type Progress = { done: number; total?: number; note?: string; steps?: string[]; at: number; since?: number }

/** One request the person made (mirrors hooks/asks.ts). */
export type Ask = { id: string; text: string; status: 'open' | 'done' | 'dropped' | 'partial' | 'answered'; proof?: string; at: number; doneAt?: number }

/** Step history for time-left guesses (mirrors hooks/eta.ts). */
export type StepTrack = {
  startedAt: number
  lastAt: number
  done: number
  total: number
  marks: { at: number; n: number; perStepMs: number }[]
}

/** A commentator line and an agent-to-agent message (mirror hooks/talk.ts). */
export type TalkLine = { at: number; text: string }
export type Msg = { at: number; from: string; to: string; text: string }

export type ToolStatus = 'run' | 'ok' | 'err'

export type ToolRow = {
  id: string
  tool: string
  label: string
  status: ToolStatus
  startedAt: number
  endedAt?: number
  /** First line of the result's text when the tool failed. */
  error?: string
}

export type RunStatus = 'running' | 'done' | 'failed' | 'idle'

export type AgentRun = {
  id: string
  /** The loop that spawned it; absent when the main loop did. */
  parentId?: string
  type: string
  description: string
  model: string
  effort?: string
  /** Its own color in the pane and the band. */
  color: string
  /** Its role from its mission (roles.ts): robot, color family, what it says. */
  role?: string
  status: RunStatus
  /** Why it ended when that was not a plain answer: error, stopped, refused, ctx full, killed. */
  endReason?: string
  /** First line of its final answer. */
  answer?: string
  /** The last model step's stop reason. */
  lastStop?: string
  startedAt: number
  endedAt?: number
  ctxTokens: number
  ctxMax: number
  /** Context fill in percent, one per model step, the last 10. */
  ctxHist: number[]
  costUsd: number
  toolCount: number
  tools: ToolRow[]
  /** When a permission ask for it began; absent when nothing waits. */
  waitSince?: number
  waitTool?: string
  /** What the agent reported through the step tool, if it did. */
  progress?: Progress
}

export type Todo = {
  content: string
  status: string
  activeForm?: string
}

export type MainLoop = {
  isBusy: boolean
  turnStartedAt: number
  /** When the last main turn ended: an ask still open after it is late. */
  turnEndedAt?: number
  model?: string
  effort?: string
  toolCount: number
  tools: ToolRow[]
  todos: Todo[]
  /** What the main loop reported through the step tool, if it did. */
  progress?: Progress
  waitSince?: number
  waitTool?: string
}

export type FileTouch = {
  path: string
  kind: 'read' | 'edit'
  at: number
  /** Who touched it last: 'main' or the agent's id (older state: its type). */
  owner: string
  /** Everyone who edited it, to warn when two did. */
  editors: string[]
}

export type Usage = {
  startedAt: number
  ctxPercent: number
  /** Tokens in the main context window. */
  ctxTokens?: number
  costUsd: number
  fiveHour?: number
  sevenDay?: number
  /** ISO times the windows reset. */
  fiveReset?: string
  sevenReset?: string
}

export type Compaction = {
  at: number
  trigger: string
  tokensBefore?: number
  tokensAfter?: number
}

export type View = {
  /** The agent whose full tool list is open, or 'main'. */
  expanded: string
  /** True: DONE shows every agent, not only the newest few. */
  isDoneAll?: boolean
  isBandHidden: boolean
  /** Which tab of the pane shows. */
  tab?: 'live' | 'timeline' | 'files'
}

declare module 'claude-code' {
  interface PluginState {
    'mission-control': {
      agents: AgentRun[]
      main: MainLoop
      files: FileTouch[]
      usage: Usage
      view: View
      tick: number
      /** How many loops wait on the person, written only when it changes. */
      waitN: number
      /** Agents spawned so far: the next one's color. */
      seq: number
      /** Usage samples for the cost graph, burn rate and run-out forecast. */
      hist: Sample[]
      /** Main-context compactions this session, newest last. */
      compactions: Compaction[]
      /** The person's requests this session, ticked by the main loop. */
      asks: Ask[]
      /** Step histories: 'main' for the todo list, else an agent id. */
      tracks: Record<string, StepTrack>
      /** The commentator: on or off, and its last lines. */
      talkOn: boolean
      talk: TalkLine[]
      /** Agent-to-agent messages. */
      msgs: Msg[]
      /** The last tool-count milestone a toast announced (every 50). */
      milestone: number
    }
  }
}
