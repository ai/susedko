import {
  writeFileSync,
  readFileSync,
  readdirSync,
  existsSync,
  rmSync
} from 'node:fs'
import { join, relative, basename } from 'node:path'
import { parse, stringify } from 'yaml'
import { fileURLToPath } from 'node:url'

const ROOT = join(fileURLToPath(import.meta.url), '..', '..')

let secrets = {}

readFileSync(join(ROOT, 'secrets.env'))
  .toString()
  .trim()
  .split('\n')
  .map(i => {
    let [name, ...value] = i.split('=')
    secrets[name] = value.join('=')
  })

function merge(base, add, path) {
  for (let key in add) {
    if (!(key in base)) {
      base[key] = add[key]
    } else if (Array.isArray(base[key]) && Array.isArray(base[key])) {
      base[key] = base[key].concat(add[key])
    } else if (typeof base[key] === 'object' && typeof add[key] === 'object') {
      merge(base[key], add[key], `${path}.${key}`)
    } else {
      process.stderr.write(`Do not know how to merge key ${path}\n`)
      process.exit(1)
    }
  }
}

function read(...parts) {
  let content = readFileSync(join(...parts)).toString()
  for (let name in secrets) {
    content = content.replaceAll('$' + name, secrets[name])
  }
  return content
}

function runLine(str) {
  return `          ${str} \\\n`
}

function generateService(file, input) {
  let name = basename(file, '.service')
  let yml = parse(input)

  if (yml.waitOnline) {
    yml.wants = (yml.wants ?? []).concat(['NetworkManager-wait-online.service'])
    yml.after = (yml.after ?? []).concat(['NetworkManager-wait-online.service'])
  }
  if (yml.podman) {
    if (yml.podman.image.startsWith('docker.io/')) {
      yml.environment = (yml.environment ?? []).concat([
        'REGISTRY_AUTH_FILE="/usr/local/etc/docker-auth.json"'
      ])
    }
    yml.execStartPre = (yml.execStartPre ?? []).concat([
      `-/bin/podman kill ${name}`,
      `-/bin/podman rm ${name}`,
      `/bin/podman pull ${yml.podman.image}`
    ])
    let run = `/bin/podman run \\\n`
    run += runLine('--tz=timezone')
    if (yml.podman.readonly) run += runLine(`--read-only`)
    for (let i of yml.podman.ports ?? []) {
      run += runLine(`-p ${i}`)
    }
    for (let key in yml.podman.env ?? {}) {
      let value = yml.podman.env[key]
      if (typeof value === 'string') {
        run += runLine(`-e ${key}="${yml.podman.env[key]}"`)
      } else {
        run += runLine(`-e ${key}=${yml.podman.env[key]}`)
      }
    }
    for (let i of yml.podman.devices ?? []) {
      run += runLine(`--device ${i}`)
    }
    for (let i of yml.podman.annotations ?? []) {
      run += runLine(`--annotation ${i}`)
    }
    for (let i of yml.podman.volumes ?? []) {
      run += runLine(`-v ${i}`)
    }
    for (let i of yml.podman.security ?? []) {
      run += runLine(`--security-opt ${i}`)
    }
    for (let i of yml.podman.sysctls ?? []) {
      run += runLine(`--sysctl ${i}`)
    }
    for (let opt of ['network', 'pid', 'userns', 'user']) {
      if (yml.podman[opt]) run += runLine(`--${opt} ${yml.podman[opt]}`)
    }
    run += runLine(`--name ${name}`)
    run += runLine(`--label "io.containers.autoupdate=registry"`)
    run += `          ${yml.podman.image}`
    yml.execStart = (yml.execStart ?? []).concat([run])
    yml.execStop = (yml.execStop ?? []).concat([
      `/bin/podman stop -t 10 ${name}`
    ])
  }

  let service = `[Unit]\nDescription=${yml.desc}\n`
  if (yml.wants) service += `Wants=${yml.wants.join(' ')}\n`
  if (yml.after) service += `After=${yml.after.join(' ')}\n`
  if (yml.restart) service += 'StartLimitBurst=2\nStartLimitInterval=11\n'

  service += `\n[Service]\n`
  if (yml.user) service += `User=${yml.user}\n`
  if (yml.group) service += `Group=${yml.group}\n`
  for (let i of yml.environmentFiles ?? []) {
    service += `EnvironmentFile=${i}\n`
  }
  for (let i of yml.environment ?? []) {
    service += `Environment=${i}\n`
  }
  for (let i of yml.execStartPre ?? []) {
    service += `ExecStartPre=${i}\n`
  }
  for (let i of yml.execStart ?? []) {
    service += `ExecStart=${i}\n`
  }
  for (let i of yml.execStop ?? []) {
    service += `ExecStop=${i}\n`
  }
  if (yml.restart) service += 'Restart=on-failure\nRestartSec=3\n'

  service += `\n[Install]\nWantedBy=multi-user.target\n`
  return service
}

function processFile(path) {
  let dir = join(path, '..')
  let parsed = parse(read(path))
  if (parsed.disabled) return

  if (parsed.not_demo) {
    if (!process.env.DEMO) {
      parsed = { ...parsed, ...parsed.not_demo }
    }
    delete parsed.not_demo
  }

  if (parsed.demo) {
    if (process.env.DEMO) {
      parsed = { ...parsed, ...parsed.demo }
    }
    delete parsed.demo
  }

  for (let unit of parsed.systemd?.units ?? []) {
    if (!unit.contents) {
      let service
      if (existsSync(join(dir, unit.name + '.yml'))) {
        service = generateService(unit.name, read(dir, unit.name + '.yml'))
      } else {
        service = read(dir, unit.name)
      }
      unit.contents = service
    }
  }

  for (let file of parsed.storage?.files ?? []) {
    if (!file.contents && !file.append) {
      file.contents = {
        inline: read(dir, basename(file.path))
      }
    }
  }

  merge(config, parsed, relative(ROOT, path))
}

let config = {}

rmSync(join(ROOT, 'config.bu'), { force: true })

readdirSync(join(ROOT, 'settings')).forEach(file => {
  processFile(join(ROOT, 'settings', file))
})
readdirSync(join(ROOT, 'units')).forEach(dir => {
  processFile(join(ROOT, 'units', dir, `${dir}.bu`))
})

let output = process.env.DEMO ? 'demo.bu' : 'config.bu'
writeFileSync(join(ROOT, output), stringify(config, { lineWidth: 0 }))
