import fs from 'fs'

// قرا JSON
const data = JSON.parse(fs.readFileSync('data.json', 'utf-8'))

// خذ headers من أول object
const headers = Object.keys(data[0])

// function باش نحول value ل CSV-safe
function formatValue(value) {
  if (Array.isArray(value)) {
    return `"${value.join(',')}"`
  }
  if (typeof value === 'string') {
    return `"${value.replace(/"/g, '""')}"`
  }
  return value
}

// build CSV
const rows = data.map(obj =>
  headers.map(h => formatValue(obj[h])).join(',')
)

const csv = [
  headers.join(','), // header row
  ...rows
].join('\n')

// كتب file
fs.writeFileSync('output.csv', csv)

console.log('CSV file created ✅')
