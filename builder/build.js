import { readFileSync, rmSync, readdirSync, writeFileSync } from 'node:fs'
import { join, relative, basename } from 'node:path'
import { parse, stringify } from 'yaml'
import { fileURLToPath } from 'node:url'

const ROOT = join(fileURLToPath(import.meta.url), '..', '..')

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
  return readFileSync(join(...parts)).toString()
}

const AI_PASSWORD = read(ROOT, 'ai.password')

function replace_envs(template) {
  return template.replace(/__AI_PASSWORD__/g, AI_PASSWORD)
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
      unit.contents = replace_envs(read(dir, unit.name))
    }
  }

  for (let file of parsed.storage?.files ?? []) {
    if (!file.contents && !file.append) {
      file.contents = {
        inline: replace_envs(read(dir, basename(file.path)))
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
