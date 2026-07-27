// Seed an in-flight dataset collaboration for UI screenshots.
const BASE = 'http://127.0.0.1:8081'
const PASSWORD = 'demo-password-1'

async function call(method, path, { token, body } = {}) {
  const headers = { 'Content-Type': 'application/json' }
  if (token) headers.Authorization = `Token ${token}`
  const res = await fetch(BASE + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) })
  const json = await res.json().catch(() => null)
  if (res.status >= 400) throw new Error(`${method} ${path} -> ${res.status} ${JSON.stringify(json)}`)
  return json?.data
}

async function ensureUser(username) {
  try {
    const r = await call('POST', '/api/register', { body: { username, email: `${username}@demo.test`, password: PASSWORD } })
    return r.token
  } catch {
    const r = await call('POST', '/api/login', { body: { identification: username, password: PASSWORD } })
    return r.token
  }
}

const requesterName = 'linzhou_demo'
const helperName = 'shenyu_data_demo'
const requester = await ensureUser(requesterName)
const helper = await ensureUser(helperName)

for (const t of [requester, helper]) {
  await call('PATCH', '/api/nexus/me/agent-profile', { token: t, body: { permissions: { allowAgentMatching: true }, userConfirmed: true } })
}

const req = await call('POST', '/api/nexus/help-requests', {
  token: requester,
  body: {
    title: '缺少可用的遥感建筑分割训练数据集',
    summary: '模型特化训练缺少可用的遥感建筑分割数据集：公开源不可用或许可不兼容，需要带许可的建筑掩膜切片',
    content: '需要约 2000 张已标注建筑掩膜切片用于课程研究，可接受校内网传输或线下交接。',
    categoryLabel: 'dataset',
    neededLabels: ['remote-sensing', 'dataset-steward'],
    urgency: 'normal',
    userConfirmed: true,
  },
})

const match = await call('POST', `/api/nexus/help-requests/${req.id}/matches`, {
  token: helper,
  body: { message: '我在课程组维护一套带许可的建筑掩膜数据集，可以协商传输方式。', userConfirmed: true },
})
await call('PATCH', `/api/nexus/matches/${match.id}`, { token: requester, body: { status: 'accepted', userConfirmed: true } })

const t1 = await call('POST', `/api/nexus/matches/${match.id}/tasks`, {
  token: helper, body: { title: '确认数据集许可范围与引用要求', ownerRole: 'helper', clientRequestId: 'demo-t1', userConfirmed: true },
})
const t2 = await call('POST', `/api/nexus/matches/${match.id}/tasks`, {
  token: helper, body: { title: '准备 2000 张标注切片并计算 SHA-256 校验和', ownerRole: 'helper', clientRequestId: 'demo-t2', userConfirmed: true },
})
await call('POST', `/api/nexus/matches/${match.id}/tasks`, {
  token: helper, body: { title: '接收后抽样验证标注质量（按 5% 抽样）', ownerRole: 'requester', clientRequestId: 'demo-t3', userConfirmed: true },
})
await call('PATCH', `/api/nexus/matches/${match.id}/tasks/${t1.id}`, { token: helper, body: { status: 'done', userConfirmed: true } })
await call('PATCH', `/api/nexus/matches/${match.id}/tasks/${t2.id}`, { token: helper, body: { status: 'doing', userConfirmed: true } })

await call('POST', `/api/nexus/matches/${match.id}/messages`, {
  token: helper,
  body: { content: '许可确认完毕：课程组内部授权，可用于课程研究，不可二次分发，引用格式我放到交付说明里。', kind: 'update', clientRequestId: 'demo-m1', userConfirmed: true },
})
await call('POST', `/api/nexus/matches/${match.id}/messages`, {
  token: requester,
  body: { content: '好的，导师已同意按这个许可使用。', userConfirmed: true },
})

await call('POST', `/api/nexus/matches/${match.id}/decisions`, {
  token: helper,
  body: {
    title: '选择数据集传输方式',
    context: '两种方式都可行：校内网 HTTP 临时链接（需要你在校园网内，当天有效），或线下 U 盘交接（图书馆一楼服务台旁，公共场所）。',
    options: [
      { key: 'campus-http', label: '校内网临时 HTTP 传输', note: '当天有效链接 + SHA-256 校验' },
      { key: 'offline-usb', label: '线下 U 盘交接', note: '图书馆一楼服务台旁，公共场所' },
    ],
    assignedRole: 'requester',
    clientRequestId: 'demo-d1',
    userConfirmed: true,
  },
})

await call('POST', `/api/nexus/matches/${match.id}/deliverables`, {
  token: helper,
  body: {
    title: '遥感建筑分割数据集 v1（2000 张切片）',
    description: '含标注说明与引用格式。先交前 500 张样例供抽样验证，其余待传输方式确定后一并交付。',
    accessHint: 'http://10.12.8.21:8000/dataset-sample.tar.gz（当天 22:00 前有效）',
    checksum: 'sha256:51a9f0f1e2d3c4b5a6978869504132231405f6e7d8c9b0a1f2e3d4c5b6a79880',
    licenseNote: '课程组内部授权，仅限本课程研究使用，不可二次分发。',
    clientRequestId: 'demo-dl1',
    userConfirmed: true,
  },
})

await call('PATCH', `/api/nexus/matches/${match.id}/workspace`, {
  token: helper, body: { baton: 'requester', note: '样例已就绪，等你确认传输方式并抽样。', userConfirmed: true },
})

console.log(JSON.stringify({ matchId: match.id, helpRequestId: req.id, requesterName, helperName, password: PASSWORD }))
