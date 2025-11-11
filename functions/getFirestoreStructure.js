import { initializeApp, cert } from "firebase-admin/app"
import { getFirestore } from "firebase-admin/firestore"
import fs from "fs"
import path from "path"

const serviceAccount = JSON.parse(
  fs.readFileSync(
    "./zyppiride-2025-firebase-adminsdk-fbsvc-8888785e38.json",
    "utf8"
  )
)

initializeApp({
  credential: cert(serviceAccount)
})

const db = getFirestore()
const ROOT = path.resolve("../structure")

if (!fs.existsSync(ROOT)) fs.mkdirSync(ROOT)

async function getFieldKeys(docRef) {
  const snap = await docRef.get()
  if (!snap.exists) return {}
  const data = snap.data() || {}
  const keys = {}
  Object.keys(data).forEach((k) => (keys[k] = null))
  return keys
}

async function getStructure() {
  const result = {}
  const treeLines = []
  const collections = await db.listCollections()

  for (const col of collections) {
    treeLines.push(col.id)
    result[col.id] = {}

    const docs = await col.listDocuments()
    const limitedDocs = docs.slice(0, 50)

    for (const doc of limitedDocs) {
      const fields = await getFieldKeys(doc)
      treeLines.push(` └─ ${doc.id}`)

      if (Object.keys(fields).length > 0) {
        for (const key of Object.keys(fields)) {
          treeLines.push(`     • ${key}`)
        }
      }

      result[col.id][doc.id] = { fields }

      const subCollections = await doc.listCollections()
      for (const sub of subCollections) {
        treeLines.push(`     └─ ${sub.id}`)
        result[col.id][doc.id][sub.id] = {}

        const subDocs = await sub.listDocuments()
        const limitedSubDocs = subDocs.slice(0, 50)

        for (const subDoc of limitedSubDocs) {
          const subFields = await getFieldKeys(subDoc)
          treeLines.push(`         └─ ${subDoc.id}`)
          for (const key of Object.keys(subFields)) {
            treeLines.push(`             • ${key}`)
          }
          result[col.id][doc.id][sub.id][subDoc.id] = { fields: subFields }
        }

        if (subDocs.length > 50) {
          treeLines.push(`         ... +${subDocs.length - 50} more docs`)
        }
      }
    }

    if (docs.length > 50) {
      treeLines.push(`   ... +${docs.length - 50} more docs`)
    }
  }

  fs.writeFileSync(
    path.join(ROOT, "firestore_structure.txt"),
    treeLines.join("\n")
  )
  fs.writeFileSync(
    path.join(ROOT, "firestore_structure.json"),
    JSON.stringify(result, null, 2)
  )

  console.log("✅ Firestore structure (with field keys) generated.")
  console.log("Output saved to '/structure' folder in root.")
}

getStructure().catch((err) => console.error(err))
