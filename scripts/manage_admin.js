#!/usr/bin/env node
/**
 * Script para gestionar administradores de MODO en Firebase Firestore.
 * Uso:
 *   node scripts/manage_admin.js add <email>
 *   node scripts/manage_admin.js remove <email>
 *   node scripts/manage_admin.js list
 */

const fs = require('fs');
const https = require('https');
const os = require('os');
const path = require('path');

const projectId = 'modo-31d0e';

function getAccessToken() {
  try {
    const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
    if (fs.existsSync(configPath)) {
      const cfg = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      if (cfg.tokens && cfg.tokens.access_token) {
        return cfg.tokens.access_token;
      }
    }
  } catch (_) {}
  return process.env.FIREBASE_TOKEN || null;
}

function requestFirestore(method, docPath, data = null) {
  const token = getAccessToken();
  if (!token) {
    console.error('Error: No se encontró token de Firebase. Ejecuta "firebase login".');
    process.exit(1);
  }

  return new Promise((resolve, reject) => {
    const payload = data ? JSON.stringify(data) : null;
    const req = https.request({
      hostname: 'firestore.googleapis.com',
      path: `/v1/projects/${projectId}/databases/(default)/documents/${docPath}`,
      method: method,
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {})
      }
    }, res => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: JSON.parse(body) });
        } catch (_) {
          resolve({ status: res.statusCode, data: body });
        }
      });
    });
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function main() {
  const [,, command, emailArg] = process.argv;

  if (!command || (command !== 'list' && !emailArg)) {
    console.log(`
Uso de MODO Admin CLI:
  node scripts/manage_admin.js add <correo@gmail.com>      Otorgar rol admin
  node scripts/manage_admin.js remove <correo@gmail.com>   Revocar rol admin
  node scripts/manage_admin.js list                        Listar administradores
`);
    return;
  }

  const email = emailArg ? emailArg.toLowerCase().trim() : '';

  if (command === 'add') {
    console.log(`Otorgando rol admin a: ${email}...`);
    const res = await requestFirestore('PATCH', `admins/${email}`, {
      fields: {
        email: { stringValue: email },
        role: { stringValue: 'admin' },
        createdAt: { timestampValue: new Date().toISOString() }
      }
    });

    if (res.status === 200) {
      console.log(`✅ ¡Éxito! El correo ${email} ahora tiene rol "admin" en MODO.`);
    } else {
      console.error(`❌ Error (${res.status}):`, res.data);
    }
  } else if (command === 'remove') {
    console.log(`Revocando rol admin a: ${email}...`);
    const res = await requestFirestore('DELETE', `admins/${email}`);
    if (res.status === 200 || res.status === 204) {
      console.log(`✅ Rol admin revocado exitosamente a ${email}.`);
    } else {
      console.error(`❌ Error (${res.status}):`, res.data);
    }
  } else if (command === 'list') {
    console.log(`Consultando lista de administradores en proyecto ${projectId}...`);
    const res = await requestFirestore('GET', 'admins');
    if (res.status === 200 && res.data.documents) {
      console.log(`\nAdministradores activos (${res.data.documents.length}):`);
      for (const doc of res.data.documents) {
        const mail = doc.fields?.email?.stringValue || doc.name.split('/').pop();
        const role = doc.fields?.role?.stringValue || 'admin';
        console.log(` • ${mail} (${role})`);
      }
    } else {
      console.log('No se encontraron administradores o la colección está vacía.');
    }
  }
}

main().catch(console.error);
