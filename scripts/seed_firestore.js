#!/usr/bin/env node
/**
 * Script de población de Firestore con 50 prendas de catálogo para MODO.
 * Soporta modo Cliente Firebase SDK y REST API.
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

const productsFilePath = path.join(__dirname, 'seed_products.json');
const products = JSON.parse(fs.readFileSync(productsFilePath, 'utf8'));

const projectId = process.env.FIREBASE_PROJECT_ID || process.argv[2] || 'modo-31d0e';

console.log(`[MODO Seeder] Iniciando sembrado de ${products.length} prendas...`);
console.log(`[MODO Seeder] Proyecto destino: ${projectId}`);

async function seedViaRest(accessToken) {
  let count = 0;
  for (const item of products) {
    const docId = item.id;
    const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/productos/${docId}`;
    
    // Convert JSON fields to Firestore REST Value map
    const fields = {};
    for (const [k, v] of Object.entries(item)) {
      if (typeof v === 'string') {
        fields[k] = { stringValue: v };
      } else if (Array.isArray(v)) {
        fields[k] = { arrayValue: { values: v.map(s => ({ stringValue: String(s) })) } };
      }
    }
    fields.updatedAt = { timestampValue: new Date().toISOString() };
    fields.createdAt = { timestampValue: new Date().toISOString() };

    const body = JSON.stringify({ fields });

    await new Promise((resolve, reject) => {
      const u = new URL(url);
      const req = https.request({
        hostname: u.hostname,
        path: u.pathname,
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`,
          'Content-Length': Buffer.byteLength(body)
        }
      }, (res) => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          count++;
          process.stdout.write(`\r[MODO Seeder] Guardado ${count}/${products.length}: ${item.name}`);
          resolve();
        } else {
          let errData = '';
          res.on('data', c => errData += c);
          res.on('end', () => reject(new Error(`HTTP ${res.statusCode}: ${errData}`)));
        }
      });
      req.on('error', reject);
      req.write(body);
      req.end();
    });
  }
  console.log(`\n[MODO Seeder] ¡Éxito! ${count} prendas registradas en Firestore.`);
}

async function main() {
  const token = process.env.FIREBASE_TOKEN || process.argv[3];
  if (!token) {
    console.log(`
Uso del script CLI:
  node scripts/seed_firestore.js [projectId] [oauth_access_token]

O mediante variables de entorno:
  FIREBASE_PROJECT_ID=modo-31d0e FIREBASE_TOKEN=<tu-token> node scripts/seed_firestore.js

Tip: También podés poblar las 50 prendas directamente con 1 solo clic desde el botón
"🌱 Sembrar 50 Prendas" en el panel web administrativo (web/index.html).
`);
    return;
  }

  try {
    await seedViaRest(token);
  } catch (err) {
    console.error('\n[Error en Seeder]:', err.message);
  }
}

main();
