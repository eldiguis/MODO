/**
 * MODO Store Admin — Optimized Web Controller
 * Project: modo-31d0e
 */

// 1. Firebase Configuration
const firebaseConfig = {
  projectId: "modo-31d0e",
  appId: "1:1061048654903:web:4276630759dfb5f2deb3b2",
  databaseURL: "https://modo-31d0e-default-rtdb.firebaseio.com",
  storageBucket: "modo-31d0e.firebasestorage.app",
  apiKey: "AIzaSyBoSe_Wp83gBdFgq4Je-w3zQRnKT4iqHiw",
  authDomain: "modo-31d0e.firebaseapp.com",
  messagingSenderId: "1061048654903",
  measurementId: "G-ZRX46K7ZMN"
};

let db = null;
let auth = null;

try {
  if (typeof firebase !== 'undefined') {
    if (!firebase.apps.length) {
      firebase.initializeApp(firebaseConfig);
    }
    db = firebase.firestore();
    auth = firebase.auth();
  }
} catch (err) {
  console.error('[Firebase Init Error]', err);
}

// 2. Constants & State
const CACHE_KEY = 'modo_admin_products_cache';
const CACHE_TIMESTAMP_KEY = 'modo_admin_cache_time';
const CACHE_TTL_MS = 3 * 60 * 1000; // 3 minutes

const STORE_LABELS = {
  store_jockey: 'Jockey Plaza',
  store_salaverry: 'Real Plaza Salaverry',
  store_san_miguel: 'Plaza San Miguel'
};

const SVG_FALLBACK_IMAGE = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='120' height='150' fill='%23898780'><rect width='120' height='150' fill='%23faf9f6'/><text x='50%' y='50%' text-anchor='middle' dy='.3em' font-family='sans-serif' font-size='11'>Sin imagen</text></svg>";

let allProducts = [];
let filteredProducts = [];
let currentPage = 0;
let pageSize = 8;
let editingId = null;
let deletingId = null;
let searchDebounceTimer = null;
let currentUser = null;
const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

// 3. DOM Elements
const loginView = document.getElementById('loginView');
const dashboardView = document.getElementById('dashboardView');
const emailLoginForm = document.getElementById('emailLoginForm');
const adminEmailInput = document.getElementById('adminEmail');
const adminPasswordInput = document.getElementById('adminPassword');
const googleLoginBtn = document.getElementById('googleLoginBtn');
const loginError = document.getElementById('loginError');
const sessionBadge = document.getElementById('sessionBadge');
const sessionLabel = document.getElementById('sessionLabel');
const logoutBtn = document.getElementById('logoutBtn');

const productForm = document.getElementById('productForm');
const formTitle = document.getElementById('formTitle');
const cancelEditBtn = document.getElementById('cancelEditBtn');
const saveProductBtn = document.getElementById('saveProductBtn');
const imageInput = document.getElementById('image');
const imagePreview = document.getElementById('imagePreview');

const productsBody = document.getElementById('productsBody');
const searchInput = document.getElementById('searchInput');
const searchClearBtn = document.getElementById('searchClearBtn');
const categoryFilter = document.getElementById('categoryFilter');
const storeFilter = document.getElementById('storeFilter');
const sortFilter = document.getElementById('sortFilter');
const pageSizeSelect = document.getElementById('pageSizeSelect');

const statTotal = document.getElementById('statTotal');
const statCats = document.getElementById('statCats');
const pagerInfo = document.getElementById('pagerInfo');
const prevPageBtn = document.getElementById('prevPageBtn');
const nextPageBtn = document.getElementById('nextPageBtn');
const pageDots = document.getElementById('pageDots');

const deleteModal = document.getElementById('deleteModal');
const deleteModalDesc = document.getElementById('deleteModalDesc');
const deleteCancelBtn = document.getElementById('deleteCancelBtn');
const deleteConfirmBtn = document.getElementById('deleteConfirmBtn');

const loadingOverlay = document.getElementById('loadingOverlay');
const loadingText = document.getElementById('loadingText');
const toastContainer = document.getElementById('toastContainer');

// 4. Utility Functions
async function checkFirebaseHealth() {
  const dot = document.getElementById('firebaseHealthDot');
  const text = document.getElementById('firebaseHealthText');
  if (!db) {
    if (dot) dot.style.background = '#c0392b';
    if (text) text.textContent = 'Firebase no disponible';
    return;
  }
  const start = Date.now();
  try {
    await db.collection('productos').limit(1).get();
    const ms = Date.now() - start;
    if (dot) dot.style.background = '#27ae60';
    if (text) text.textContent = `Firebase OK (${ms}ms)`;
  } catch (err) {
    if (dot) dot.style.background = '#c0392b';
    if (text) text.textContent = 'Error Firebase: ' + (err.code || 'falló');
  }
}

function showToast(message, type = 'success') {
  if (!toastContainer) return;
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.textContent = message;
  toastContainer.appendChild(toast);
  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateY(10px)';
    setTimeout(() => toast.remove(), 250);
  }, 3200);
}

function showLoading(text = 'Cargando catálogo…') {
  if (loadingOverlay) {
    if (loadingText) loadingText.textContent = text;
    loadingOverlay.classList.remove('hidden');
  }
}

function hideLoading() {
  if (loadingOverlay) loadingOverlay.classList.add('hidden');
}

function showView(name) {
  document.querySelectorAll('.view').forEach(v => {
    v.classList.remove('active');
    v.style.display = 'none';
  });
  const el = document.getElementById(name);
  if (el) {
    el.style.display = 'block';
    el.classList.add('active');
  }
}

function cleanString(val) {
  return typeof val === 'string' ? val.trim() : '';
}

function formatPriceDisplay(price) {
  if (typeof price === 'number') {
    return `S/ ${price.toFixed(2)}`;
  }
  const str = cleanString(price);
  if (!str) return 'S/ 0';
  if (str.startsWith('S/')) return str;
  return `S/ ${str}`;
}

function parsePriceNumber(price) {
  if (typeof price === 'number') return price;
  const num = parseFloat(String(price).replace(/[^\d.-]/g, ''));
  return isNaN(num) ? 0 : num;
}

// 5. Cache Layer
function getCachedProducts() {
  try {
    const raw = localStorage.getItem(CACHE_KEY);
    const time = localStorage.getItem(CACHE_TIMESTAMP_KEY);
    if (!raw || !time) return null;
    if (Date.now() - parseInt(time, 10) > CACHE_TTL_MS) {
      localStorage.removeItem(CACHE_KEY);
      localStorage.removeItem(CACHE_TIMESTAMP_KEY);
      return null;
    }
    return JSON.parse(raw);
  } catch (_) {
    return null;
  }
}

function setCachedProducts(items) {
  try {
    localStorage.setItem(CACHE_KEY, JSON.stringify(items));
    localStorage.setItem(CACHE_TIMESTAMP_KEY, Date.now().toString());
  } catch (_) {}
}

function invalidateCache() {
  try {
    localStorage.removeItem(CACHE_KEY);
    localStorage.removeItem(CACHE_TIMESTAMP_KEY);
  } catch (_) {}
}

// 6. Firestore Catalog Service
async function fetchProductsFromFirestore() {
  if (!db) throw new Error('Firestore no está disponible.');
  const snapshot = await db.collection('productos').get();
  const items = snapshot.docs.map(doc => {
    const d = doc.data();
    return {
      id: doc.id,
      name: d.name || d.nombre || 'Prenda sin nombre',
      category: d.category || d.categoria || 'Hombre',
      price: d.price || d.precio || '0',
      image: d.image || d.imageUrl || d.imagen || SVG_FALLBACK_IMAGE,
      store: d.tienda || d.store || 'store_jockey',
      tag: d.tag || d.etiqueta || '',
      color: d.color || '',
      sizes: Array.isArray(d.sizes) ? d.sizes : (typeof d.sizes === 'string' ? d.sizes.split(',').map(s => s.trim()).filter(Boolean) : []),
      material: d.material || '',
      fit: d.fit || '',
      care: d.care || '',
      description: d.description || '',
      updatedAt: d.updatedAt || null
    };
  });
  return items;
}

async function loadProducts(forceRefresh = false) {
  showLoading('Obteniendo prendas...');
  try {
    if (!forceRefresh) {
      const cached = getCachedProducts();
      if (cached && Array.isArray(cached) && cached.length > 0) {
        allProducts = cached;
        applyFilters();
        hideLoading();
        return;
      }
    }
    allProducts = await fetchProductsFromFirestore();
    setCachedProducts(allProducts);
    applyFilters();
  } catch (err) {
    showToast('Error cargando catálogo: ' + (err.message || err), 'error');
  } finally {
    hideLoading();
  }
}

// 7. Filtering, Sorting & Pagination
function applyFilters() {
  const query = cleanString(searchInput.value).toLowerCase();
  const cat = categoryFilter.value;
  const store = storeFilter.value;
  const sort = sortFilter.value;

  filteredProducts = allProducts.filter(item => {
    if (cat && item.category !== cat) return false;
    if (store && item.store !== store) return false;
    if (query) {
      const matchName = item.name.toLowerCase().includes(query);
      const matchTag = item.tag.toLowerCase().includes(query);
      const matchColor = item.color.toLowerCase().includes(query);
      if (!matchName && !matchTag && !matchColor) return false;
    }
    return true;
  });

  // Sorting
  filteredProducts.sort((a, b) => {
    if (sort === 'price_asc') return parsePriceNumber(a.price) - parsePriceNumber(b.price);
    if (sort === 'price_desc') return parsePriceNumber(b.price) - parsePriceNumber(a.price);
    if (sort === 'name_asc') return a.name.localeCompare(b.name);
    return 0; // newest / default order
  });

  currentPage = 0;
  updateStats();
  renderTable();
  updatePager();
}

function updateStats() {
  if (statTotal) statTotal.textContent = allProducts.length;
  if (statCats) {
    const cats = new Set(allProducts.map(p => p.category));
    statCats.textContent = cats.size;
  }
}

function renderTable() {
  if (!productsBody) return;
  productsBody.innerHTML = '';

  if (filteredProducts.length === 0) {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td colspan="6" style="text-align:center;padding:36px;color:var(--muted);">No se encontraron prendas con los filtros aplicados.</td>`;
    productsBody.appendChild(tr);
    return;
  }

  const start = currentPage * pageSize;
  const pageItems = filteredProducts.slice(start, start + pageSize);

  pageItems.forEach(item => {
    const tr = document.createElement('tr');
    const storeLabel = STORE_LABELS[item.store] || item.store;
    const tagBadge = item.tag ? `<span class="badge lime" style="margin-left:6px;">${item.tag}</span>` : '';

    tr.innerHTML = `
      <td>
        <img class="product-thumb" src="${item.image || SVG_FALLBACK_IMAGE}" alt="${item.name}" loading="lazy" onerror="this.src='${SVG_FALLBACK_IMAGE}';" />
      </td>
      <td>
        <strong>${item.name}</strong>
        ${tagBadge}
        ${item.color ? `<div class="muted" style="font-size:12px;">Color: ${item.color}</div>` : ''}
      </td>
      <td><span class="badge">${item.category}</span></td>
      <td><strong>${formatPriceDisplay(item.price)}</strong></td>
      <td><span class="muted">${storeLabel}</span></td>
      <td>
        <div class="actions-cell">
          <button type="button" class="btn sm" data-action="edit" data-id="${item.id}">Editar</button>
          <button type="button" class="btn sm danger" data-action="delete" data-id="${item.id}">Eliminar</button>
        </div>
      </td>
    `;
    productsBody.appendChild(tr);
  });
}

function updatePager() {
  const total = filteredProducts.length;
  const totalPages = Math.max(1, Math.ceil(total / pageSize));

  if (pagerInfo) {
    if (total === 0) {
      pagerInfo.textContent = 'Mostrando 0 prendas';
    } else {
      const start = currentPage * pageSize + 1;
      const end = Math.min((currentPage + 1) * pageSize, total);
      pagerInfo.textContent = `Mostrando ${start}–${end} de ${total} prendas`;
    }
  }

  if (prevPageBtn) prevPageBtn.disabled = currentPage === 0;
  if (nextPageBtn) nextPageBtn.disabled = currentPage >= totalPages - 1;

  if (pageDots) {
    pageDots.innerHTML = '';
    const maxDots = 5;
    let startPage = Math.max(0, currentPage - 2);
    let endPage = Math.min(totalPages, startPage + maxDots);
    if (endPage - startPage < maxDots) {
      startPage = Math.max(0, endPage - maxDots);
    }

    for (let i = startPage; i < endPage; i++) {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = `page-dot ${i === currentPage ? 'active' : ''}`;
      btn.textContent = (i + 1).toString();
      btn.addEventListener('click', () => {
        currentPage = i;
        renderTable();
        updatePager();
      });
      pageDots.appendChild(btn);
    }
  }
}

// 8. Product Actions (CRUD)
function startEdit(id) {
  const p = allProducts.find(x => x.id === id);
  if (!p) return;
  editingId = id;

  if (formTitle) formTitle.textContent = 'Editar prenda';
  if (saveProductBtn) saveProductBtn.textContent = 'Actualizar prenda';
  if (cancelEditBtn) cancelEditBtn.classList.remove('hidden');

  document.getElementById('productId').value = id;
  document.getElementById('name').value = p.name;
  document.getElementById('category').value = p.category;
  document.getElementById('price').value = p.price;
  document.getElementById('image').value = p.image;
  imagePreview.src = p.image || SVG_FALLBACK_IMAGE;
  document.getElementById('store').value = p.store || 'store_jockey';
  document.getElementById('tag').value = p.tag;
  document.getElementById('color').value = p.color;
  document.getElementById('sizes').value = p.sizes.join(', ');
  document.getElementById('material').value = p.material;
  document.getElementById('fit').value = p.fit;
  document.getElementById('care').value = p.care;
  document.getElementById('description').value = p.description;

  // Scroll smoothly to form on mobile
  if (window.innerWidth < 1100) {
    productForm.scrollIntoView({ behavior: 'smooth' });
  }
}

function resetForm() {
  editingId = null;
  if (formTitle) formTitle.textContent = 'Agregar prenda';
  if (saveProductBtn) saveProductBtn.textContent = 'Guardar prenda';
  if (cancelEditBtn) cancelEditBtn.classList.add('hidden');
  productForm.reset();
  document.getElementById('productId').value = '';
  imagePreview.src = SVG_FALLBACK_IMAGE;
}

productForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  if (!db) {
    showToast('Firestore no está disponible', 'error');
    return;
  }

  const nameVal = cleanString(document.getElementById('name').value);
  const catVal = cleanString(document.getElementById('category').value);
  const priceVal = cleanString(document.getElementById('price').value);
  const imageVal = cleanString(document.getElementById('image').value);
  const storeVal = cleanString(document.getElementById('store').value);
  const tagVal = cleanString(document.getElementById('tag').value);
  const colorVal = cleanString(document.getElementById('color').value);
  const sizesRaw = cleanString(document.getElementById('sizes').value);
  const sizesArr = sizesRaw ? sizesRaw.split(',').map(s => s.trim()).filter(Boolean) : [];
  const materialVal = cleanString(document.getElementById('material').value);
  const fitVal = cleanString(document.getElementById('fit').value);
  const careVal = cleanString(document.getElementById('care').value);
  const descVal = cleanString(document.getElementById('description').value);

  // Synchronized bilingual payload for full Flutter compatibility
  const payload = {
    name: nameVal,
    nombre: nameVal,
    category: catVal,
    categoria: catVal,
    price: priceVal,
    precio: priceVal,
    image: imageVal,
    imageUrl: imageVal,
    imagen: imageVal,
    store: storeVal,
    tienda: storeVal,
    tag: tagVal || catVal,
    etiqueta: tagVal || catVal,
    sizes: sizesArr,
    color: colorVal,
    material: materialVal,
    fit: fitVal,
    care: careVal,
    description: descVal,
    updatedAt: firebase.firestore.FieldValue.serverTimestamp()
  };

  showLoading(editingId ? 'Actualizando prenda…' : 'Guardando prenda…');
  try {
    if (editingId) {
      await db.collection('productos').doc(editingId).set(payload, { merge: true });
      showToast(`"${nameVal}" actualizada con éxito.`);
    } else {
      payload.createdAt = firebase.firestore.FieldValue.serverTimestamp();
      await db.collection('productos').add(payload);
      showToast(`"${nameVal}" agregada al catálogo.`);
    }
    resetForm();
    invalidateCache();
    await loadProducts(true);
  } catch (err) {
    showToast('Error al guardar: ' + err.message, 'error');
  } finally {
    hideLoading();
  }
});

// Table delegate for Edit / Delete actions
productsBody.addEventListener('click', (e) => {
  const target = e.target.closest('button');
  if (!target) return;
  const action = target.getAttribute('data-action');
  const id = target.getAttribute('data-id');
  if (!id) return;

  if (action === 'edit') {
    startEdit(id);
  } else if (action === 'delete') {
    const item = allProducts.find(x => x.id === id);
    deletingId = id;
    if (deleteModalDesc) {
      deleteModalDesc.textContent = `¿Estás seguro de eliminar "${item ? item.name : 'esta prenda'}"? Esta acción no se puede deshacer.`;
    }
    deleteModal.classList.remove('hidden');
  }
});

deleteCancelBtn.addEventListener('click', () => {
  deletingId = null;
  deleteModal.classList.add('hidden');
});

deleteConfirmBtn.addEventListener('click', async () => {
  if (!deletingId || !db) return;
  deleteModal.classList.add('hidden');
  showLoading('Eliminando prenda…');
  try {
    await db.collection('productos').doc(deletingId).delete();
    showToast('Prenda eliminada del catálogo.');
    deletingId = null;
    invalidateCache();
    await loadProducts(true);
  } catch (err) {
    showToast('Error al eliminar: ' + err.message, 'error');
  } finally {
    hideLoading();
  }
});

// Seed 50 products action
const seed50Btn = document.getElementById('seed50Btn');
if (seed50Btn) {
  seed50Btn.addEventListener('click', async () => {
    if (!db) {
      showToast('Firestore no está disponible.', 'error');
      return;
    }
    const list = window.SEED_PRODUCTS_50;
    if (!list || !Array.isArray(list) || list.length === 0) {
      showToast('No se encontraron los datos del seed.', 'error');
      return;
    }
    if (!confirm(`¿Deseas poblar Firestore con ${list.length} prendas oficiales (Hombre, Mujer, Niños, Niñas, Accesorios)?`)) {
      return;
    }
    showLoading(`Sembrando ${list.length} prendas en Firestore…`);
    try {
      const batch = db.batch();
      list.forEach(item => {
        const docRef = db.collection('productos').doc(item.id);
        const docData = Object.assign({}, item, {
          updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
          createdAt: firebase.firestore.FieldValue.serverTimestamp()
        });
        batch.set(docRef, docData, { merge: true });
      });
      await batch.commit();
      showToast(`¡${list.length} prendas sembradas con éxito!`);
      invalidateCache();
      await loadProducts(true);
    } catch (err) {
      showToast('Error sembrando catálogo: ' + err.message, 'error');
    } finally {
      hideLoading();
    }
  });
}

cancelEditBtn.addEventListener('click', resetForm);

// Image preview live update with error handling
imageInput.addEventListener('input', (e) => {
  const url = cleanString(e.target.value);
  imagePreview.src = url || SVG_FALLBACK_IMAGE;
});
imagePreview.addEventListener('error', () => {
  imagePreview.src = SVG_FALLBACK_IMAGE;
});

// Search input debounced
searchInput.addEventListener('input', () => {
  if (searchClearBtn) {
    searchClearBtn.classList.toggle('visible', searchInput.value.length > 0);
  }
  clearTimeout(searchDebounceTimer);
  searchDebounceTimer = setTimeout(applyFilters, 280);
});

searchClearBtn.addEventListener('click', () => {
  searchInput.value = '';
  searchClearBtn.classList.remove('visible');
  applyFilters();
});

categoryFilter.addEventListener('change', applyFilters);
storeFilter.addEventListener('change', applyFilters);
sortFilter.addEventListener('change', applyFilters);
pageSizeSelect.addEventListener('change', (e) => {
  pageSize = parseInt(e.target.value, 10) || 8;
  currentPage = 0;
  renderTable();
  updatePager();
});

prevPageBtn.addEventListener('click', () => {
  if (currentPage > 0) {
    currentPage--;
    renderTable();
    updatePager();
  }
});

nextPageBtn.addEventListener('click', () => {
  const totalPages = Math.ceil(filteredProducts.length / pageSize);
  if (currentPage < totalPages - 1) {
    currentPage++;
    renderTable();
    updatePager();
  }
});

// 9. Authentication Flow
function handleUserLoggedIn(user) {
  currentUser = user;
  if (sessionBadge) sessionBadge.classList.remove('hidden');
  if (sessionLabel) sessionLabel.textContent = user.displayName || user.email || 'Admin';
  if (logoutBtn) logoutBtn.classList.remove('hidden');
  showView('dashboardView');

  if (window.gsap && !prefersReducedMotion) {
    gsap.from('.dashboard-grid > .panel', {
      y: 20,
      opacity: 0,
      duration: 0.5,
      stagger: 0.08,
      ease: 'power2.out'
    });
  }

  loadProducts();
}

function handleUserLoggedOut() {
  currentUser = null;
  if (sessionBadge) sessionBadge.classList.add('hidden');
  if (logoutBtn) logoutBtn.classList.add('hidden');
  showView('loginView');
}

async function verifyAdminRoleAndLogin(user) {
  if (!user || !user.email) {
    if (auth && auth.currentUser) await auth.signOut();
    loginError.textContent = 'No se pudo obtener el correo de la cuenta de Google.';
    handleUserLoggedOut();
    return;
  }

  const email = user.email.toLowerCase().trim();
  showLoading('Verificando privilegios de administrador…');

  try {
    const adminDoc = await db.collection('admins').doc(email).get();

    if (adminDoc.exists && adminDoc.data().role === 'admin') {
      showToast(`Acceso concedido: ${user.displayName || email}`);
      handleUserLoggedIn(user);
    } else {
      console.warn(`[Acceso Denegado] ${email} no tiene rol admin en Firestore.`);
      if (auth && auth.currentUser) {
        await auth.signOut();
      }
      handleUserLoggedOut();
      loginError.textContent = `Acceso denegado: El correo "${email}" no cuenta con permisos de administrador en MODO.`;
    }
  } catch (err) {
    console.error('Error al verificar admin en Firestore:', err);
    if (auth && auth.currentUser) await auth.signOut();
    handleUserLoggedOut();
    loginError.textContent = 'Error al verificar permisos en la base de datos: ' + (err.message || err);
  } finally {
    hideLoading();
  }
}

// Email & Password Sign-In con Verificación de Rol Admin
if (emailLoginForm) {
  emailLoginForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!auth || !db) {
      loginError.textContent = 'Firebase Auth o Firestore no están inicializados.';
      return;
    }
    const email = adminEmailInput ? adminEmailInput.value.trim() : '';
    const password = adminPasswordInput ? adminPasswordInput.value : '';

    if (!email || !password) {
      loginError.textContent = 'Por favor ingresa tu correo y contraseña.';
      return;
    }

    loginError.textContent = '';
    showLoading('Autenticando administrador…');

    try {
      const userCredential = await auth.signInWithEmailAndPassword(email, password);
      await verifyAdminRoleAndLogin(userCredential.user);
    } catch (err) {
      console.error('Email Admin Sign-In Error:', err);
      if (err.code === 'auth/user-not-found' || err.code === 'auth/wrong-password' || err.code === 'auth/invalid-credential') {
        loginError.textContent = 'Correo o contraseña incorrectos.';
      } else if (err.code === 'auth/too-many-requests') {
        loginError.textContent = 'Demasiados intentos fallidos. Intenta más tarde.';
      } else {
        loginError.textContent = err.message || 'Error al iniciar sesión.';
      }
    } finally {
      hideLoading();
    }
  });
}

// Google OAuth Sign-In Exclusivo con Verificación de Rol Admin
googleLoginBtn.addEventListener('click', async () => {
  if (!auth || !db) {
    loginError.textContent = 'Firebase Auth o Firestore no están inicializados.';
    return;
  }
  loginError.textContent = '';
  showLoading('Conectando con Google…');
  try {
    const provider = new firebase.auth.GoogleAuthProvider();
    provider.addScope('profile');
    provider.addScope('email');
    provider.setCustomParameters({ prompt: 'select_account' });

    const userCredential = await auth.signInWithPopup(provider);
    await verifyAdminRoleAndLogin(userCredential.user);
  } catch (err) {
    console.error('Google Sign-In Error:', err);
    if (err.code === 'auth/popup-blocked' || err.code === 'auth/cancelled-popup-request') {
      try {
        showLoading('Redirigiendo a Google…');
        const provider = new firebase.auth.GoogleAuthProvider();
        provider.setCustomParameters({ prompt: 'select_account' });
        await auth.signInWithRedirect(provider);
        return;
      } catch (redirectErr) {
        loginError.textContent = redirectErr.message;
      }
    } else if (err.code === 'auth/configuration-not-found') {
      loginError.textContent = 'Error de configuración de Auth en Firebase. Revisa el dominio autorizado en Firebase Console.';
    } else {
      loginError.textContent = err.message || 'Error al autenticar con Google.';
    }
  } finally {
    hideLoading();
  }
});

logoutBtn.addEventListener('click', async () => {
  if (auth && auth.currentUser) {
    await auth.signOut();
  }
  handleUserLoggedOut();
});

// Process Google Redirect Result & listen for Firebase Auth changes con validación de admin
if (auth) {
  auth.getRedirectResult().then(async (result) => {
    if (result && result.user) {
      await verifyAdminRoleAndLogin(result.user);
    }
  }).catch((err) => {
    console.error('Redirect sign-in error:', err);
    loginError.textContent = err.message || 'Error en autenticación redirigida.';
  });

  auth.onAuthStateChanged(async (user) => {
    if (user) {
      if (!currentUser || currentUser.uid !== user.uid) {
        await verifyAdminRoleAndLogin(user);
      }
    } else {
      handleUserLoggedOut();
    }
  });
}

// Background slideshow
(function bgSlideshow() {
  if (prefersReducedMotion) return;
  const slides = document.querySelectorAll('.login-bg .bg-slide');
  if (!slides.length) return;
  let i = 0;
  setInterval(() => {
    slides[i].classList.remove('active');
    i = (i + 1) % slides.length;
    slides[i].classList.add('active');
    if (window.gsap) {
      gsap.fromTo(slides[i], { opacity: 0, scale: 1.05 }, { opacity: 1, scale: 1, duration: 1.2 });
    }
  }, 4200);
})();

// Health check on load
checkFirebaseHealth();
