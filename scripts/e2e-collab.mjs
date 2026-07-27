// E2E acceptance: "missing training dataset" — two agents negotiate and
// deliver through the post-match collaboration workspace.
// Covers: happy path, interruption recovery, duplicate requests (idempotency),
// failure handling (reject -> resubmit), pause control, and isolation (403s).
const BASE = process.env.NEXUS_BASE || 'http://127.0.0.1:8081'

let passed = 0, failed = 0
const failures = []
function check(name, cond, extra) {
  if (cond) { passed++; console.log(`  PASS  ${name}`) }
  else { failed++; failures.push(name); console.log(`  FAIL  ${name}${extra ? ' — ' + JSON.stringify(extra).slice(0, 300) : ''}`) }
}

async function call(method, path, { token, body } = {}) {
  const headers = { 'Content-Type': 'application/json' }
  if (token) headers.Authorization = `Token ${token}`
  const res = await fetch(BASE + path, {
    method, headers, body: body === undefined ? undefined : JSON.stringify(body),
  })
  let json = null
  try { json = await res.json() } catch { /* empty body */ }
  return { status: res.status, data: json?.data, raw: json }
}

async function register(username) {
  const email = `${username}@e2e.test`
  const password = 'e2e-password-1'
  let r = await call('POST', '/api/register', { body: { username, email, password } })
  if (r.status !== 200) r = await call('POST', '/api/login', { body: { identification: username, password } })
  return { token: r.data.token, username }
}

const ts = Date.now().toString(36)
const scenario = async () => {
  console.log(`\n== Setup: two users + a bystander (base ${BASE}) ==`)
  const requester = await register(`ds_requester_${ts}`)
  const helper = await register(`ds_helper_${ts}`)
  const outsider = await register(`ds_outsider_${ts}`)
  check('three users registered', !!requester.token && !!helper.token && !!outsider.token)

  // The outsider also enables matching so that isolation tests hit the
  // participant check (403), not the permission-switch check (400).
  for (const u of [requester, helper, outsider]) {
    const r = await call('PATCH', '/api/nexus/me/agent-profile', {
      token: u.token,
      body: { permissions: { allowAgentMatching: true }, userConfirmed: true },
    })
    check(`${u.username} enabled allowAgentMatching`, r.status === 200, r.raw)
  }

  console.log('\n== Phase 1: requester agent publishes the dataset help request ==')
  const reqCreate = await call('POST', '/api/nexus/help-requests', {
    token: requester.token,
    body: {
      title: '缺少可用的遥感建筑分割训练数据集',
      summary: '公开检索失败：需要带许可的建筑掩膜数据用于课程模型特化训练',
      content: '公开数据源不可用或许可不兼容。需要约 2000 张已标注切片，可接受校内传输或线下交接。',
      categoryLabel: 'dataset',
      neededLabels: ['remote-sensing', 'dataset-steward'],
      urgency: 'normal',
      userConfirmed: true,
    },
  })
  check('help request created', reqCreate.status === 200 && reqCreate.data?.id, reqCreate.raw)
  const helpId = reqCreate.data.id

  console.log('\n== Phase 2: helper agent offers, requester human accepts ==')
  const offer = await call('POST', `/api/nexus/help-requests/${helpId}/matches`, {
    token: helper.token,
    body: { message: '我这边有课程组授权的建筑掩膜数据集，可以协商传输方式。', meetingSafetyState: 'not_arranged', userConfirmed: true },
  })
  check('match offered', offer.status === 200 && offer.data?.status === 'offered', offer.raw)
  const matchId = offer.data.id

  const accept = await call('PATCH', `/api/nexus/matches/${matchId}`, {
    token: requester.token, body: { status: 'accepted', userConfirmed: true },
  })
  check('match accepted by requester', accept.status === 200 && accept.data?.status === 'accepted', accept.raw)
  check('accepted match exposes collaborationState', accept.data?.collaborationState === 'active', accept.data)

  console.log('\n== Phase 3: helper agent bootstraps workspace and plans tasks ==')
  const ws0 = await call('GET', `/api/nexus/matches/${matchId}/workspace`, { token: helper.token })
  check('workspace loads for helper', ws0.status === 200 && ws0.data?.viewerRole === 'helper', ws0.raw)
  check('workspace has match.accepted event', ws0.data.events.some(e => e.eventType === 'match.accepted'), ws0.data.events)
  let lastEventId = ws0.data.lastEventId

  const t1 = await call('POST', `/api/nexus/matches/${matchId}/tasks`, {
    token: helper.token,
    body: { title: '确认数据集许可范围与引用要求', ownerRole: 'helper', clientRequestId: 'task-license', userConfirmed: true },
  })
  const t2 = await call('POST', `/api/nexus/matches/${matchId}/tasks`, {
    token: helper.token,
    body: { title: '准备 2000 张标注切片并计算校验和', ownerRole: 'helper', clientRequestId: 'task-package', userConfirmed: true },
  })
  const t3 = await call('POST', `/api/nexus/matches/${matchId}/tasks`, {
    token: helper.token,
    body: { title: '接收后抽样验证标注质量', ownerRole: 'requester', clientRequestId: 'task-verify', userConfirmed: true },
  })
  check('three tasks created', [t1, t2, t3].every(r => r.status === 200), { t1: t1.status, t2: t2.status, t3: t3.status })

  const t1Replay = await call('POST', `/api/nexus/matches/${matchId}/tasks`, {
    token: helper.token,
    body: { title: '确认数据集许可范围与引用要求', ownerRole: 'helper', clientRequestId: 'task-license', userConfirmed: true },
  })
  check('duplicate task create returns original (idempotent)', t1Replay.status === 200 && t1Replay.data.id === t1.data.id, t1Replay.raw)

  const msg1 = await call('POST', `/api/nexus/matches/${matchId}/messages`, {
    token: helper.token,
    body: { content: '数据集为课程组内部授权，可用于课程研究，不可二次分发。', kind: 'update', clientRequestId: 'msg-license', userConfirmed: true },
  })
  check('agent update message sent', msg1.status === 200 && msg1.data?.kind === 'update', msg1.raw)
  const msg1Replay = await call('POST', `/api/nexus/matches/${matchId}/messages`, {
    token: helper.token,
    body: { content: '数据集为课程组内部授权，可用于课程研究，不可二次分发。', kind: 'update', clientRequestId: 'msg-license', userConfirmed: true },
  })
  check('duplicate message returns original (idempotent)', msg1Replay.status === 200 && msg1Replay.data.id === msg1.data.id, msg1Replay.raw)

  console.log('\n== Phase 4: decision gate — transfer method needs the requester human ==')
  const dec = await call('POST', `/api/nexus/matches/${matchId}/decisions`, {
    token: helper.token,
    body: {
      title: '选择数据集传输方式',
      context: '两种方式都可行：校内网 HTTP 临时链接（需要你在校园网内），或线下 U 盘交接（图书馆一楼，公共场所）。',
      options: [
        { key: 'campus-http', label: '校内网临时 HTTP 传输', note: '当天有效链接 + SHA-256 校验' },
        { key: 'offline-usb', label: '线下 U 盘交接', note: '图书馆一楼服务台旁，公共场所' },
      ],
      assignedRole: 'requester',
      clientRequestId: 'dec-transfer',
      userConfirmed: true,
    },
  })
  check('decision opened', dec.status === 200 && dec.data?.status === 'open', dec.raw)
  const decId = dec.data.id
  const decReplay = await call('POST', `/api/nexus/matches/${matchId}/decisions`, {
    token: helper.token,
    body: { title: '选择数据集传输方式', options: [{ key: 'a', label: 'x' }, { key: 'b', label: 'y' }], assignedRole: 'requester', clientRequestId: 'dec-transfer', userConfirmed: true },
  })
  check('duplicate decision returns original (idempotent)', decReplay.status === 200 && decReplay.data.id === decId, decReplay.raw)

  const selfAssigned = await call('POST', `/api/nexus/matches/${matchId}/decisions`, {
    token: helper.token,
    body: {
      title: '自问自答的决策',
      options: [{ key: 'a', label: 'A' }, { key: 'b', label: 'B' }],
      assignedRole: 'helper',
      userConfirmed: true,
    },
  })
  check('self-assigned decision rejected (400)', selfAssigned.status === 400, selfAssigned.raw)

  const helperDecide = await call('PATCH', `/api/nexus/matches/${matchId}/decisions/${decId}`, {
    token: helper.token, body: { action: 'decide', optionKey: 'campus-http', userConfirmed: true },
  })
  check('non-assigned role cannot decide (403)', helperDecide.status === 403, helperDecide.raw)

  const reqWork = await call('GET', '/api/nexus/me/work-items', { token: requester.token })
  check('requester work queue surfaces pending decision',
    reqWork.status === 200 && reqWork.data?.some(w => w.kind === 'match_decision' && w.id === decId),
    { status: reqWork.status, data: reqWork.data })

  const decide = await call('PATCH', `/api/nexus/matches/${matchId}/decisions/${decId}`, {
    token: requester.token,
    body: { action: 'decide', optionKey: 'campus-http', note: '本周都在校园网内，选校内传输。', userConfirmed: true },
  })
  check('requester human decided campus-http', decide.status === 200 && decide.data?.decidedOptionKey === 'campus-http', decide.raw)

  const decideReplay = await call('PATCH', `/api/nexus/matches/${matchId}/decisions/${decId}`, {
    token: requester.token, body: { action: 'decide', optionKey: 'campus-http', userConfirmed: true },
  })
  check('re-deciding same option is idempotent', decideReplay.status === 200 && decideReplay.data?.status === 'decided', decideReplay.raw)
  const decideConflict = await call('PATCH', `/api/nexus/matches/${matchId}/decisions/${decId}`, {
    token: requester.token, body: { action: 'decide', optionKey: 'offline-usb', userConfirmed: true },
  })
  check('re-deciding different option rejected (400)', decideConflict.status === 400, decideConflict.raw)

  console.log('\n== Phase 5: baton handoff + pause intervention ==')
  const baton = await call('PATCH', `/api/nexus/matches/${matchId}/workspace`, {
    token: requester.token, body: { baton: 'helper', note: '方案已定，等你打包数据。', userConfirmed: true },
  })
  check('baton passed to helper', baton.status === 200 && baton.data?.batonRole === 'helper', baton.raw)

  const pause = await call('PATCH', `/api/nexus/matches/${matchId}/workspace`, {
    token: requester.token, body: { collaborationState: 'paused', note: '先确认导师同意再继续。', userConfirmed: true },
  })
  check('requester paused collaboration', pause.status === 200 && pause.data?.collaborationState === 'paused', pause.raw)

  const pausedTask = await call('POST', `/api/nexus/matches/${matchId}/tasks`, {
    token: helper.token, body: { title: '暂停期间不应能创建', userConfirmed: true },
  })
  check('paused workspace rejects new task (400)', pausedTask.status === 400, pausedTask.raw)
  const pausedMsg = await call('POST', `/api/nexus/matches/${matchId}/messages`, {
    token: helper.token, body: { content: '好的，等你们确认。', userConfirmed: true },
  })
  check('messages still allowed while paused', pausedMsg.status === 200, pausedMsg.raw)

  const resume = await call('PATCH', `/api/nexus/matches/${matchId}/workspace`, {
    token: requester.token, body: { collaborationState: 'active', note: '导师已同意。', userConfirmed: true },
  })
  check('collaboration resumed', resume.status === 200 && resume.data?.collaborationState === 'active', resume.raw)

  console.log('\n== Phase 6: task progression incl. blocked -> recovered ==')
  const doing = await call('PATCH', `/api/nexus/matches/${matchId}/tasks/${t2.data.id}`, {
    token: helper.token, body: { status: 'doing', userConfirmed: true },
  })
  check('task moved to doing', doing.status === 200 && doing.data?.status === 'doing', doing.raw)
  const blocked = await call('PATCH', `/api/nexus/matches/${matchId}/tasks/${t2.data.id}`, {
    token: helper.token, body: { status: 'blocked', blockedReason: '标注文件缺 300 张，需要重新导出。', userConfirmed: true },
  })
  check('task blocked with reason', blocked.status === 200 && blocked.data?.status === 'blocked', blocked.raw)
  const blockedNoReason = await call('PATCH', `/api/nexus/matches/${matchId}/tasks/${t1.data.id}`, {
    token: helper.token, body: { status: 'blocked', userConfirmed: true },
  })
  check('blocking without reason rejected (400)', blockedNoReason.status === 400, blockedNoReason.raw)
  await call('PATCH', `/api/nexus/matches/${matchId}/tasks/${t2.data.id}`, {
    token: helper.token, body: { status: 'doing', userConfirmed: true },
  })
  for (const t of [t1, t2]) {
    await call('PATCH', `/api/nexus/matches/${matchId}/tasks/${t.data.id}`, {
      token: helper.token, body: { status: 'done', userConfirmed: true },
    })
  }

  console.log('\n== Phase 7: isolation — outsider is locked out everywhere ==')
  const oWs = await call('GET', `/api/nexus/matches/${matchId}/workspace`, { token: outsider.token })
  check('outsider workspace read -> 403', oWs.status === 403, oWs.raw)
  const oEvents = await call('GET', `/api/nexus/matches/${matchId}/events`, { token: outsider.token })
  check('outsider events read -> 403', oEvents.status === 403, oEvents.raw)
  const oMsg = await call('GET', `/api/nexus/matches/${matchId}/messages`, { token: outsider.token })
  check('outsider messages read -> 403', oMsg.status === 403, oMsg.raw)
  const oTask = await call('POST', `/api/nexus/matches/${matchId}/tasks`, {
    token: outsider.token, body: { title: '入侵任务', userConfirmed: true },
  })
  check('outsider task create -> 403', oTask.status === 403, oTask.raw)
  const anon = await call('GET', `/api/nexus/matches/${matchId}/workspace`)
  check('anonymous workspace read -> 401/403', anon.status === 401 || anon.status === 403, anon.status)

  console.log('\n== Phase 7b: server-enforced protocol — completion gates, cancel rights, baton ==')
  // Open a fresh gate; the raiser is the helper, assigned to the requester.
  const guardDec = await call('POST', `/api/nexus/matches/${matchId}/decisions`, {
    token: helper.token,
    body: {
      title: '是否需要补充验证集切片',
      options: [{ key: 'yes', label: '需要' }, { key: 'no', label: '不需要' }],
      assignedRole: 'requester', clientRequestId: 'dec-guard', userConfirmed: true,
    },
  })
  check('guard decision opened', guardDec.status === 200 && guardDec.data?.status === 'open', guardDec.raw)

  const nonRaiserCancel = await call('PATCH', `/api/nexus/matches/${matchId}/decisions/${guardDec.data.id}`, {
    token: requester.token, body: { action: 'cancel', userConfirmed: true },
  })
  check('non-raiser cannot cancel decision (403)', nonRaiserCancel.status === 403, nonRaiserCancel.raw)

  const helperComplete = await call('PATCH', `/api/nexus/matches/${matchId}`, {
    token: helper.token, body: { status: 'completed', userConfirmed: true },
  })
  check('helper cannot complete match (403)', helperComplete.status === 403, helperComplete.raw)

  const completeWithOpenGate = await call('PATCH', `/api/nexus/matches/${matchId}`, {
    token: requester.token, body: { status: 'completed', userConfirmed: true },
  })
  check('open decision blocks completion (400)', completeWithOpenGate.status === 400, completeWithOpenGate.raw)

  const raiserCancel = await call('PATCH', `/api/nexus/matches/${matchId}/decisions/${guardDec.data.id}`, {
    token: helper.token, body: { action: 'cancel', note: '样例阶段先不需要。', userConfirmed: true },
  })
  check('raiser can cancel own decision', raiserCancel.status === 200 && raiserCancel.data?.status === 'cancelled', raiserCancel.raw)

  // Baton is with the helper (passed in Phase 5); the requester must take it
  // before pushing new work, and taking it is an explicit, evented act.
  const batonBlocked = await call('POST', `/api/nexus/matches/${matchId}/tasks`, {
    token: requester.token, body: { title: '未持棒时新增任务', userConfirmed: true },
  })
  check('non-holder task create blocked by baton (400)', batonBlocked.status === 400, batonBlocked.raw)

  const takeBaton = await call('PATCH', `/api/nexus/matches/${matchId}/workspace`, {
    token: requester.token, body: { baton: 'requester', note: '我先补充一个验证任务。', userConfirmed: true },
  })
  check('requester takes the baton explicitly', takeBaton.status === 200 && takeBaton.data?.batonRole === 'requester', takeBaton.raw)

  const afterTake = await call('POST', `/api/nexus/matches/${matchId}/tasks`, {
    token: requester.token,
    body: { title: '记录抽样验证标准', ownerRole: 'requester', clientRequestId: 'task-criteria', userConfirmed: true },
  })
  check('baton holder can create work', afterTake.status === 200, afterTake.raw)

  const foreignAdvance = await call('PATCH', `/api/nexus/matches/${matchId}/tasks/${t2.data.id}`, {
    token: requester.token, body: { status: 'doing', userConfirmed: true },
  })
  check('non-owner cannot advance counterpart task (403)', foreignAdvance.status === 403, foreignAdvance.raw)

  const giveBack = await call('PATCH', `/api/nexus/matches/${matchId}/workspace`, {
    token: requester.token, body: { baton: 'helper', note: '轮到你打包交付。', userConfirmed: true },
  })
  check('baton handed back to helper', giveBack.status === 200 && giveBack.data?.batonRole === 'helper', giveBack.raw)

  console.log('\n== Phase 8: delivery — reject once (failure handling), then accept ==')
  const d1 = await call('POST', `/api/nexus/matches/${matchId}/deliverables`, {
    token: helper.token,
    body: {
      title: '遥感建筑分割数据集 v1（2000 张切片）',
      description: '校内网临时 HTTP 链接当天有效，含标注说明。',
      accessHint: 'http://10.12.8.21:8000/dataset-v1.tar.gz（当天 22:00 前有效）',
      checksum: 'sha256:51a9f0f1e2d3c4b5a6978869504132231405f6e7d8c9b0a1f2e3d4c5b6a79880',
      licenseNote: '课程组内部授权，仅限本课程研究使用，不可二次分发。',
      clientRequestId: 'deliv-v1',
      userConfirmed: true,
    },
  })
  check('deliverable v1 submitted', d1.status === 200 && d1.data?.status === 'submitted', d1.raw)
  const d1Replay = await call('POST', `/api/nexus/matches/${matchId}/deliverables`, {
    token: helper.token, body: { title: '遥感建筑分割数据集 v1（2000 张切片）', clientRequestId: 'deliv-v1', userConfirmed: true },
  })
  check('duplicate deliverable returns original (idempotent)', d1Replay.status === 200 && d1Replay.data.id === d1.data.id, d1Replay.raw)

  const earlyComplete = await call('PATCH', `/api/nexus/matches/${matchId}`, {
    token: requester.token, body: { status: 'completed', userConfirmed: true },
  })
  check('completion blocked while deliverable pending (400)', earlyComplete.status === 400, earlyComplete.raw)

  const selfReview = await call('PATCH', `/api/nexus/matches/${matchId}/deliverables/${d1.data.id}`, {
    token: helper.token, body: { action: 'accept', userConfirmed: true },
  })
  check('submitter cannot review own deliverable (403)', selfReview.status === 403, selfReview.raw)

  const reviewQueue = await call('GET', '/api/nexus/me/work-items', { token: requester.token })
  check('requester work queue surfaces pending review',
    reviewQueue.status === 200 && reviewQueue.data?.some(w => w.kind === 'match_deliverable' && w.id === d1.data.id),
    { status: reviewQueue.status, data: reviewQueue.data })

  const reject = await call('PATCH', `/api/nexus/matches/${matchId}/deliverables/${d1.data.id}`, {
    token: requester.token,
    body: { action: 'reject', reviewNote: '抽样发现 12% 切片缺少掩膜，请补齐后重新提交。', userConfirmed: true },
  })
  check('deliverable v1 rejected with note', reject.status === 200 && reject.data?.status === 'rejected', reject.raw)

  const d2 = await call('POST', `/api/nexus/matches/${matchId}/deliverables`, {
    token: helper.token,
    body: {
      title: '遥感建筑分割数据集 v2（补齐缺失掩膜）',
      description: '补齐缺失掩膜并重新打包，新校验和如下。',
      accessHint: 'http://10.12.8.21:8000/dataset-v2.tar.gz（当天 22:00 前有效）',
      checksum: 'sha256:8c7b6a5948372615049382716a5b4c3d2e1f00998877665544332211aabbccdd',
      licenseNote: '同 v1：课程组内部授权，不可二次分发。',
      clientRequestId: 'deliv-v2',
      userConfirmed: true,
    },
  })
  check('deliverable v2 submitted', d2.status === 200 && d2.data?.status === 'submitted', d2.raw)

  console.log('\n== Phase 8b: concurrent duplicate requests — all get the same record ==')
  const concurrentTasks = await Promise.all(Array.from({ length: 8 }, () =>
    call('POST', `/api/nexus/matches/${matchId}/tasks`, {
      token: helper.token,
      body: { title: '并发重试产生的任务', ownerRole: 'helper', clientRequestId: 'task-concurrent', userConfirmed: true },
    })))
  check('8 concurrent duplicate task creates all return 200',
    concurrentTasks.every(r => r.status === 200),
    concurrentTasks.map(r => r.status))
  check('8 concurrent duplicate task creates share one id',
    new Set(concurrentTasks.map(r => r.data?.id)).size === 1,
    concurrentTasks.map(r => r.data?.id))

  const concurrentMsgs = await Promise.all(Array.from({ length: 6 }, () =>
    call('POST', `/api/nexus/matches/${matchId}/messages`, {
      token: helper.token,
      body: { content: '并发重试的同一条消息', kind: 'update', clientRequestId: 'msg-concurrent', userConfirmed: true },
    })))
  check('6 concurrent duplicate messages all return 200',
    concurrentMsgs.every(r => r.status === 200),
    concurrentMsgs.map(r => r.status))
  check('6 concurrent duplicate messages share one id',
    new Set(concurrentMsgs.map(r => r.data?.id)).size === 1,
    concurrentMsgs.map(r => r.data?.id))

  console.log('\n== Phase 8c: human controls survive allowAgentMatching being off ==')
  const permOff = await call('PATCH', '/api/nexus/me/agent-profile', {
    token: requester.token,
    body: { permissions: { allowAgentMatching: false }, userConfirmed: true },
  })
  check('requester disabled allowAgentMatching', permOff.status === 200, permOff.raw)

  const pauseNoPerm = await call('PATCH', `/api/nexus/matches/${matchId}/workspace`, {
    token: requester.token, body: { collaborationState: 'paused', userConfirmed: true },
  })
  check('human can still pause without agent permission', pauseNoPerm.status === 200 && pauseNoPerm.data?.collaborationState === 'paused', pauseNoPerm.raw)
  const resumeNoPerm = await call('PATCH', `/api/nexus/matches/${matchId}/workspace`, {
    token: requester.token, body: { collaborationState: 'active', userConfirmed: true },
  })
  check('human can still resume without agent permission', resumeNoPerm.status === 200 && resumeNoPerm.data?.collaborationState === 'active', resumeNoPerm.raw)

  const agentWriteNoPerm = await call('POST', `/api/nexus/matches/${matchId}/tasks`, {
    token: requester.token, body: { title: '权限关闭时的 Agent 写入', userConfirmed: true },
  })
  check('agent work creation still requires allowAgentMatching (400)', agentWriteNoPerm.status === 400, agentWriteNoPerm.raw)

  const permBack = await call('PATCH', '/api/nexus/me/agent-profile', {
    token: requester.token,
    body: { permissions: { allowAgentMatching: true }, userConfirmed: true },
  })
  check('requester re-enabled allowAgentMatching', permBack.status === 200, permBack.raw)

  console.log('\n== Phase 9: interruption recovery — helper agent "restarts" ==')
  const wsResume = await call('GET', `/api/nexus/matches/${matchId}/workspace`, { token: helper.token })
  check('workspace snapshot rebuilds full state', wsResume.status === 200
    && wsResume.data.tasks.length === 5
    && wsResume.data.decisions.length === 2
    && wsResume.data.deliverables.length === 2, {
      tasks: wsResume.data?.tasks?.length, decisions: wsResume.data?.decisions?.length, deliverables: wsResume.data?.deliverables?.length,
    })
  const delta = await call('GET', `/api/nexus/matches/${matchId}/events?afterId=${lastEventId}`, { token: helper.token })
  check('incremental events since bootstrap are retrievable', delta.status === 200 && delta.data.length > 0, delta.data?.length)
  check('event ids strictly increase', delta.data.every((e, i, a) => i === 0 || e.id > a[i - 1].id))
  const wsReplayTask = await call('POST', `/api/nexus/matches/${matchId}/tasks`, {
    token: helper.token, body: { title: '重启后重放旧请求', clientRequestId: 'task-license', userConfirmed: true },
  })
  check('replay after restart still returns original task', wsReplayTask.status === 200 && wsReplayTask.data.id === t1.data.id, wsReplayTask.raw)

  console.log('\n== Phase 10: acceptance and completion ==')
  const accept2 = await call('PATCH', `/api/nexus/matches/${matchId}/deliverables/${d2.data.id}`, {
    token: requester.token, body: { action: 'accept', reviewNote: '抽样验证通过，校验和一致。', userConfirmed: true },
  })
  check('deliverable v2 accepted', accept2.status === 200 && accept2.data?.status === 'accepted', accept2.raw)

  await call('PATCH', `/api/nexus/matches/${matchId}/tasks/${t3.data.id}`, {
    token: requester.token, body: { status: 'done', userConfirmed: true },
  })
  // Close out the extra tasks created in phases 7b/8b (each by its owner side).
  const criteriaTask = (await call('GET', `/api/nexus/matches/${matchId}/workspace`, { token: requester.token }))
    .data.tasks.find(t => t.title === '记录抽样验证标准')
  await call('PATCH', `/api/nexus/matches/${matchId}/tasks/${criteriaTask.id}`, {
    token: requester.token, body: { status: 'done', userConfirmed: true },
  })
  const concurrentTask = concurrentTasks[0].data
  await call('PATCH', `/api/nexus/matches/${matchId}/tasks/${concurrentTask.id}`, {
    token: helper.token, body: { status: 'done', userConfirmed: true },
  })

  const complete = await call('PATCH', `/api/nexus/matches/${matchId}`, {
    token: requester.token, body: { status: 'completed', userConfirmed: true },
  })
  check('match completed', complete.status === 200 && complete.data?.status === 'completed', complete.raw)

  const reqAfter = await call('GET', `/api/nexus/help-requests/${helpId}`)
  check('help request closed', reqAfter.data?.status === 'closed', reqAfter.data)

  const wsFinal = await call('GET', `/api/nexus/matches/${matchId}/workspace`, { token: requester.token })
  check('workspace history readable after completion', wsFinal.status === 200 && wsFinal.data.matchStatus === 'completed')
  check('progress shows all tasks done + deliverable accepted',
    wsFinal.data.progress.tasksDone === 5 && wsFinal.data.progress.tasksTotal === 5
      && wsFinal.data.progress.deliverableAccepted === true, wsFinal.data.progress)
  check('timeline recorded completion', wsFinal.data.events.some(e => e.eventType === 'match.completed'))

  const postTask = await call('POST', `/api/nexus/matches/${matchId}/tasks`, {
    token: helper.token, body: { title: '完成后不能再加任务', userConfirmed: true },
  })
  check('completed workspace rejects new work (400)', postTask.status === 400, postTask.raw)

  return matchId
}

scenario()
  .then((matchId) => {
    console.log(`\n===== E2E RESULT: ${passed} passed, ${failed} failed (match #${matchId}) =====`)
    if (failures.length) { console.log('Failed checks:', failures) ; process.exit(1) }
  })
  .catch((error) => { console.error('E2E crashed:', error); process.exit(1) })
