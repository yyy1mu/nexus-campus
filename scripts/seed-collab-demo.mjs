// Seed an in-flight edge-vision calibration collaboration for UI screenshots.
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
const helperName = 'shenyu_vision_demo'
const requester = await ensureUser(requesterName)
const helper = await ensureUser(helperName)

for (const t of [requester, helper]) {
  await call('PATCH', '/api/nexus/me/agent-profile', { token: t, body: { permissions: { allowAgentMatching: true }, userConfirmed: true } })
}

const req = await call('POST', '/api/nexus/help-requests', {
  token: requester,
  body: {
    title: '边缘视觉芯片 INT8 部署缺少目标传感器域校准数据',
    summary: '边缘视觉芯片 INT8 部署缺少目标传感器域校准数据',
    content: '现有 FP32 模型转换到边缘 NPU 后准确率明显下降，需要约 2000 帧来自目标 CMOS 传感器与 ISP 管线的匿名校准/评估数据，仅用于芯片原型验证。',
    categoryLabel: 'dataset',
    neededLabels: ['edge-vision', 'sensor-data-steward'],
    urgency: 'normal',
    userConfirmed: true,
  },
})

const match = await call('POST', `/api/nexus/help-requests/${req.id}/matches`, {
  token: helper,
  body: { message: '我们实验室维护一套同型号 CMOS 传感器采集数据，已完成脱敏并获准用于校内芯片原型校准，可以协商安全交付方式。', userConfirmed: true },
})
await call('PATCH', `/api/nexus/matches/${match.id}`, { token: requester, body: { status: 'accepted', userConfirmed: true } })

const t1 = await call('POST', `/api/nexus/matches/${match.id}/tasks`, {
  token: helper, body: { title: '确认目标 CMOS 传感器、ISP 配置与数据授权边界', ownerRole: 'helper', clientRequestId: 'demo-t1', userConfirmed: true },
})
const t2 = await call('POST', `/api/nexus/matches/${match.id}/tasks`, {
  token: helper, body: { title: '准备 2000 帧匿名校准样本、清单与 SHA-256', ownerRole: 'helper', clientRequestId: 'demo-t2', userConfirmed: true },
})
await call('POST', `/api/nexus/matches/${match.id}/tasks`, {
  token: helper, body: { title: '在边缘 NPU 上完成 INT8 校准并复测准确率与时延', ownerRole: 'requester', clientRequestId: 'demo-t3', userConfirmed: true },
})
await call('PATCH', `/api/nexus/matches/${match.id}/tasks/${t1.id}`, { token: helper, body: { status: 'done', userConfirmed: true } })
await call('PATCH', `/api/nexus/matches/${match.id}/tasks/${t2.id}`, { token: helper, body: { status: 'doing', userConfirmed: true } })

await call('POST', `/api/nexus/matches/${match.id}/messages`, {
  token: helper,
  body: { content: '授权边界已确认：人脸与车牌已脱敏，只能用于校内边缘视觉芯片的量化校准和评估，不得训练身份识别模型或二次分发。', kind: 'update', clientRequestId: 'demo-m1', userConfirmed: true },
})
await call('POST', `/api/nexus/matches/${match.id}/messages`, {
  token: requester,
  body: { content: '好的，流片项目负责人已确认传感器型号、ISP 版本和这次使用范围。', userConfirmed: true },
})

await call('POST', `/api/nexus/matches/${match.id}/decisions`, {
  token: helper,
  body: {
    title: '选择校准数据的安全交付方式',
    context: '两种方式都符合授权边界：校内网限时 HTTPS（需在校园网内，当天有效），或实验室加密 SSD 交接（现场核对设备编号与接收人）。',
    options: [
      { key: 'campus-https', label: '校内网限时 HTTPS', note: '当天有效链接 + SHA-256 校验' },
      { key: 'encrypted-ssd', label: '实验室加密 SSD 交接', note: '现场核对设备编号与接收人' },
    ],
    assignedRole: 'requester',
    clientRequestId: 'demo-d1',
    userConfirmed: true,
  },
})

await call('POST', `/api/nexus/matches/${match.id}/deliverables`, {
  token: helper,
  body: {
    title: '目标 CMOS 传感器 INT8 校准集 v1（2000 帧）',
    description: '含匿名帧、采集场景清单、传感器/ISP 元数据和许可说明。先交 500 帧样例供量化回归检查，其余待交付方式确定后一并提供。',
    accessHint: 'https://10.12.8.21:8443/edge-int8-calibration-sample.tar.zst（当天 22:00 前有效）',
    checksum: 'sha256:51a9f0f1e2d3c4b5a6978869504132231405f6e7d8c9b0a1f2e3d4c5b6a79880',
    licenseNote: '仅限校内边缘视觉芯片原型的量化校准与评估，不得用于身份识别或二次分发。',
    clientRequestId: 'demo-dl1',
    userConfirmed: true,
  },
})

await call('PATCH', `/api/nexus/matches/${match.id}/workspace`, {
  token: helper, body: { baton: 'requester', note: '校准样例和元数据已就绪，等你确认交付方式并运行 INT8 回归。', userConfirmed: true },
})

console.log(JSON.stringify({ matchId: match.id, helpRequestId: req.id, requesterName, helperName, password: PASSWORD }))
