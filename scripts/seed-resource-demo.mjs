// Explicit, repeatable local demo seeding through the real catalog API. Node 18+.
import { readFile, writeFile, mkdir } from 'node:fs/promises'
import { randomBytes } from 'node:crypto'
import { fileURLToPath } from 'node:url'

const base = new URL(process.env.NEXUS_DEMO_BASE_URL || 'http://127.0.0.1:8080')
if (!['localhost', '127.0.0.1', '[::1]'].includes(base.hostname)) {
  throw new Error('Demo seeding is limited to localhost.')
}
const fixtures = JSON.parse(await readFile(new URL('./fixtures/resource-demo.json', import.meta.url), 'utf8'))
const stateDir = new URL('../.local/', import.meta.url)
const stateFile = new URL(`resource-demo-${base.port || '80'}.json`, stateDir)
const remove = process.argv.includes('--remove')
let credentials
try { credentials = JSON.parse(await readFile(stateFile, 'utf8')) }
catch (error) {
  if (error.code !== 'ENOENT') throw error
  if (remove) throw new Error('No local demo account state found.')
  credentials = { username: 'nexus_resources_demo', email: 'nexus-resources-demo@example.invalid', password: randomBytes(24).toString('hex') }
  await mkdir(stateDir, { recursive: true, mode: 0o700 })
  await writeFile(stateFile, JSON.stringify(credentials, null, 2), { mode: 0o600, flag: 'wx' })
}

async function call(method, path, body, token) {
  const response = await fetch(new URL(path, base), {
    method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Token ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body), signal: AbortSignal.timeout(15000),
  })
  const result = await response.json().catch(() => null)
  if (!response.ok) {
    const error = new Error(`${method} ${path}: HTTP ${response.status}`)
    error.status = response.status
    throw error
  }
  return result.data
}
let session
try { session = await call('POST', '/api/login', { identification: credentials.username, password: credentials.password }) }
catch (error) {
  if (error.status !== 400 || remove) throw error
  session = await call('POST', '/api/register', credentials)
}
let created = 0, skipped = 0, removed = 0
try {
  const existing = new Map()
  for (const kind of ['skill', 'mcp']) {
    let page = 0, listing
    do {
      listing = await call('GET', `/api/nexus/resources?kind=${kind}&scope=mine&page=${page}`, undefined, session.token)
      for (const resource of listing.items) existing.set(`${kind}:${resource.sourceUrl}`, resource)
      page++
    } while (page < listing.totalPages)
  }
  for (const fixture of fixtures) {
    const sourceUrl = `https://example.invalid/nexus-demo/${fixture.kind}/${fixture.slug}`
    const prior = existing.get(`${fixture.kind}:${sourceUrl}`)
    if (remove) {
      if (prior) { await call('DELETE', `/api/nexus/resources/${prior.id}`, undefined, session.token); removed++ }
      continue
    }
    if (prior) { skipped++; continue }
    const resource = await call('POST', '/api/nexus/resources', {
      kind: fixture.kind, name: fixture.name, category: fixture.category, summary: fixture.summary,
      description: '【MOCK 演示数据】仅用于展示与交互验证，项目地址、服务和命令均为占位示例，不可直接安装或连接。\n\n' + fixture.description,
      sourceUrl, installCommand: fixture.installCommand || '',
      endpoint: fixture.kind === 'mcp' && fixture.transport !== 'stdio'
        ? `https://example.invalid/nexus-demo/${fixture.slug}/${fixture.transport === 'sse' ? 'sse' : 'mcp'}` : '',
      transport: fixture.transport || '', authType: fixture.authType || '',
    }, session.token)
    created++
    if (fixture.favorite) await call('PUT', `/api/nexus/resources/${resource.id}/favorite`, undefined, session.token)
  }
  console.log(JSON.stringify({ created, skipped, removed, skills: new URL('/skills', base).href, mcp: new URL('/mcp-servers', base).href }))
  console.log(`Demo account credentials are stored locally at ${fileURLToPath(stateFile)} (not committed).`)
} finally {
  await call('POST', '/api/logout', undefined, session.token)
}
