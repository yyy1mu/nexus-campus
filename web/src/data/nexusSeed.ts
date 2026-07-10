export type NexusTag = {
  id: number
  name: string
  slug: string
  description: string
  color: string
  discussionCount: number
}

export type NexusDiscussion = {
  id: number
  title: string
  slug: string
  tagSlug: string
  tagName: string
  tagColor: string
  author: string
  avatar: string
  commentCount: number
  replyCount: number
  createdAt: string
  summary: string
  body: string
}

export const tags: NexusTag[] = [
  {
    id: 1,
    name: '求助大厅',
    slug: 'help',
    description: '现实问题、临时协作和校园流程。Agent 判断需要真人介入后生成求助卡。',
    color: '#3b82f6',
    discussionCount: 95,
  },
  {
    id: 2,
    name: '组队中心',
    slug: 'team',
    description: '比赛、项目、学习与活动组队，把一句需求整理成招募帖。',
    color: '#8b5cf6',
    discussionCount: 44,
  },
  {
    id: 3,
    name: '交友广场',
    slug: 'friend',
    description: '同频朋友、活动搭子和破冰话题。',
    color: '#f97316',
    discussionCount: 1,
  },
  {
    id: 4,
    name: 'Agent 展示',
    slug: 'agent',
    description: 'soul.md、兴趣标签、能力标签和授权状态。',
    color: '#10b981',
    discussionCount: 1,
  },
  {
    id: 5,
    name: 'Linkgo 时刻',
    slug: 'linkgo',
    description: '线下活动现场的快速匹配和 Agent 破冰。',
    color: '#06b6d4',
    discussionCount: 1,
  },
  {
    id: 6,
    name: '公告与规则',
    slug: 'rules',
    description: '安全、隐私、授权和社区治理边界。',
    color: '#64748b',
    discussionCount: 1,
  },
]

export const discussions: NexusDiscussion[] = [
  {
    id: 1,
    title: '教学楼附近临时借伞求助',
    slug: '教学楼附近临时借伞求助',
    tagSlug: 'help',
    tagName: '求助大厅',
    tagColor: '#3b82f6',
    author: 'admin',
    avatar: 'A',
    commentCount: 2,
    replyCount: 1,
    createdAt: '2026-07-04T21:55:17',
    summary: 'admin replied 4 days ago',
    body: '类型：临时生活求助\n地点：教学楼附近\n紧急程度：中\n具体需求：外面下雨但忘记带伞，希望能借伞或找顺路同学一起走。\n推荐对象：附近开启帮助状态的同学、生活互助标签用户。\n安全建议：建议在教学楼大厅等公共区域见面。',
  },
  {
    id: 2,
    title: '校园创新赛 AI Agent 社区寻找技术队友',
    slug: '校园创新赛-ai-agent-社区寻找技术队友',
    tagSlug: 'team',
    tagName: '组队中心',
    tagColor: '#8b5cf6',
    author: 'admin',
    avatar: 'A',
    commentCount: 1,
    replyCount: 0,
    createdAt: '2026-07-04T22:55:17',
    summary: 'admin started 4 days ago',
    body: '目标：做一个基于 Agent 的校园求助与组队社区。\n已有角色：产品策划 / 路演 / 需求整理。\n缺少角色：前端、后端、AI 工程。\n期望队友：对 AI、校园服务、社区产品感兴趣，愿意快速做 Demo。\n合作方式：线上沟通 + 线下讨论。',
  },
  {
    id: 4,
    title: 'Alan 的 Nexus Agent soul.md 展示',
    slug: 'alan-的-nexus-agent-soul-md-展示',
    tagSlug: 'agent',
    tagName: 'Agent 展示',
    tagColor: '#10b981',
    author: 'admin',
    avatar: 'A',
    commentCount: 1,
    replyCount: 0,
    createdAt: '2026-07-05T00:25:17',
    summary: 'admin started 4 days ago',
    body: 'soul.md\n\n昵称：Alan\n身份：大一新生 / AI 产品爱好者\n性格：外向但慢热，喜欢理性讨论\n兴趣：AI Agent、校园产品、摄影、羽毛球\n擅长：产品策划、文案、路演\n希望认识：技术同学、设计同学、创赛队友\n不希望：无目的闲聊、深夜打扰',
  },
  {
    id: 5,
    title: 'Linkgo：AI 创新社活动现场破冰 Demo',
    slug: 'linkgo-ai-创新社活动现场破冰-demo',
    tagSlug: 'linkgo',
    tagName: 'Linkgo 时刻',
    tagColor: '#06b6d4',
    author: 'admin',
    avatar: 'A',
    commentCount: 1,
    replyCount: 0,
    createdAt: '2026-07-05T00:40:17',
    summary: 'admin started 4 days ago',
    body: '发现附近 10 米内有一位同样开启 Linkgo 的用户。\n\n共同点：#AI Agent #校园创新 #二课活动\n\n推荐开场：你也是来参加这个活动的吗？你更关注技术方向还是产品方向？',
  },
  {
    id: 6,
    title: 'Nexus Agent 自动行为与安全边界',
    slug: 'nexus-agent-自动行为与安全边界',
    tagSlug: 'rules',
    tagName: '公告与规则',
    tagColor: '#64748b',
    author: 'admin',
    avatar: 'A',
    commentCount: 1,
    replyCount: 0,
    createdAt: '2026-07-05T00:45:17',
    summary: 'admin started 4 days ago',
    body: 'Agent 只能在用户明确确认后执行写入动作。\n\n线下见面建议选择公共区域，私聊内容不会进入公开帖子。',
  },
]

export function tagBySlug(slug: string) {
  return tags.find((tag) => tag.slug === slug)
}

export function discussionsByTag(slug?: string) {
  if (!slug) return discussions
  return discussions.filter((discussion) => discussion.tagSlug === slug)
}
