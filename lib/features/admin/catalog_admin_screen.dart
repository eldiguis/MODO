import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const Color _ink = Color(0xFF171717);
const Color _paper = Color(0xFFFAF9F6);
const Color _lime = Color(0xFFD7FF55);
const Color _line = Color(0xFFE6E4DE);
const Color _muted = Color(0xFF898780);

class CatalogAdminScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const CatalogAdminScreen({super.key, required this.onLogout});

  @override
  State<CatalogAdminScreen> createState() => _CatalogAdminScreenState();
}

class _CatalogAdminScreenState extends State<CatalogAdminScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedCategory = 'Todos';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  final List<String> _categories = [
    'Todos',
    'Sacos',
    'Pantalones',
    'Remeras',
    'Vestidos',
    'Calzado',
    'Accesorios',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openProductDialog({Map<String, dynamic>? product, String? docId}) {
    showDialog(
      context: context,
      builder: (context) => _ProductFormDialog(
        product: product,
        docId: docId,
        onSave: (data, id) async {
          try {
            if (id != null) {
              await _firestore.collection('productos').doc(id).update(data);
            } else {
              await _firestore.collection('productos').add(data);
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: _ink,
                  content: Text(
                    id != null ? 'Prenda actualizada con éxito' : 'Nueva prenda agregada al catálogo',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.red.shade800,
                  content: Text('Error al guardar en Firestore: $e'),
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _deleteProduct(String docId, String productName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar Prenda', style: TextStyle(color: _ink, fontWeight: FontWeight.bold)),
        content: Text('¿Seguro que deseás eliminar "$productName" del catálogo disponible?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: _muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('productos').doc(docId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: _ink, content: Text('Prenda eliminada.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.red.shade800, content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleStock(String docId, bool currentStock) async {
    try {
      await _firestore.collection('productos').doc(docId).update({
        'inStock': !currentStock,
        'disponible': !currentStock,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red.shade800, content: Text('Error al cambiar stock: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: _line, height: 1),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _lime,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'ADMIN',
                style: TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Backoffice de Catálogo',
              style: TextStyle(
                color: _ink,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () => _openProductDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nueva Prenda'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _ink,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Cerrar Sesión Administrador',
            icon: const Icon(Icons.logout, color: _ink),
            onPressed: widget.onLogout,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra de filtros y búsqueda
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  // Buscador
                  SizedBox(
                    width: 320,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Buscar prendas por nombre...',
                        hintStyle: const TextStyle(color: _muted, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: _muted, size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _line),
                        ),
                      ),
                    ),
                  ),
                  // Filtros de categoría
                  Wrap(
                    spacing: 8,
                    children: _categories.map((cat) {
                      final selected = _selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(cat),
                        selected: selected,
                        onSelected: (val) {
                          if (val) setState(() => _selectedCategory = cat);
                        },
                        selectedColor: _ink,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : _ink,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 12,
                        ),
                        side: BorderSide(color: selected ? _ink : _line),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Lista de productos desde Firestore en tiempo real
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _firestore.collection('productos').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_off, size: 48, color: Colors.red.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'Error al conectar con Firestore:\n${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: _muted, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: _ink));
                    }

                    final docs = snapshot.data?.docs ?? [];
                    final filteredDocs = docs.where((doc) {
                      final data = doc.data();
                      final name = (data['name'] ?? data['nombre'] ?? '').toString().toLowerCase();
                      final category = (data['category'] ?? data['categoria'] ?? '').toString().toLowerCase();

                      final matchesQuery = _searchQuery.isEmpty || name.contains(_searchQuery);
                      final matchesCategory = _selectedCategory == 'Todos' ||
                          category == _selectedCategory.toLowerCase();

                      return matchesQuery && matchesCategory;
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 48, color: _muted.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            const Text(
                              'No se encontraron prendas con los filtros seleccionados.',
                              style: TextStyle(color: _muted, fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () => _openProductDialog(),
                              icon: const Icon(Icons.add, size: 16, color: _ink),
                              label: const Text('Agregar primera prenda', style: TextStyle(color: _ink)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: _line),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: filteredDocs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data();
                        final name = data['name'] ?? data['nombre'] ?? 'Sin nombre';
                        final category = data['category'] ?? data['categoria'] ?? 'General';
                        final price = data['price'] ?? data['precio'] ?? '0';
                        final image = data['image'] ?? data['imageUrl'] ?? data['foto'] ?? '';
                        final inStock = data['inStock'] ?? data['disponible'] ?? true;
                        final sizes = (data['sizes'] as List?)?.join(', ') ?? 'S, M, L';

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _line),
                          ),
                          child: Row(
                            children: [
                              // Miniatura
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  color: _paper,
                                  child: image.isNotEmpty
                                      ? Image.network(
                                          image,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => const Icon(
                                            Icons.image_not_supported_outlined,
                                            color: _muted,
                                          ),
                                        )
                                      : const Icon(Icons.checkroom, color: _muted),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Información
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            color: _ink,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _paper,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: _line),
                                          ),
                                          child: Text(
                                            category,
                                            style: const TextStyle(fontSize: 11, color: _muted),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Talles: $sizes • Precio: S/ $price',
                                      style: const TextStyle(fontSize: 13, color: _muted),
                                    ),
                                  ],
                                ),
                              ),
                              // Toggle de Stock en vivo
                              Row(
                                children: [
                                  Text(
                                    inStock ? 'Disponible' : 'Agotado',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: inStock ? Colors.green.shade700 : Colors.red.shade600,
                                    ),
                                  ),
                                  Switch(
                                    value: inStock,
                                    activeThumbColor: _ink,
                                    activeTrackColor: _lime,
                                    onChanged: (_) => _toggleStock(doc.id, inStock),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              // Acciones
                              IconButton(
                                tooltip: 'Editar Prenda',
                                icon: const Icon(Icons.edit_outlined, size: 20, color: _ink),
                                onPressed: () => _openProductDialog(product: data, docId: doc.id),
                              ),
                              IconButton(
                                tooltip: 'Eliminar Prenda',
                                icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade700),
                                onPressed: () => _deleteProduct(doc.id, name),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductFormDialog extends StatefulWidget {
  final Map<String, dynamic>? product;
  final String? docId;
  final Future<void> Function(Map<String, dynamic> data, String? id) onSave;

  const _ProductFormDialog({this.product, this.docId, required this.onSave});

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _imageCtrl;
  late final TextEditingController _tagCtrl;
  String _category = 'Sacos';
  bool _inStock = true;
  bool _isSaving = false;

  final Map<String, bool> _sizes = {
    'S': true,
    'M': true,
    'L': true,
    'XL': false,
  };

  @override
  void initState() {
    super.initState();
    final p = widget.product ?? {};
    _nameCtrl = TextEditingController(text: p['name'] ?? p['nombre'] ?? '');
    _priceCtrl = TextEditingController(text: (p['price'] ?? p['precio'] ?? '120').toString());
    _imageCtrl = TextEditingController(text: p['image'] ?? p['imageUrl'] ?? p['foto'] ?? '');
    _tagCtrl = TextEditingController(text: p['tag'] ?? p['etiqueta'] ?? 'Nuevo');
    _category = p['category'] ?? p['categoria'] ?? 'Sacos';
    _inStock = p['inStock'] ?? p['disponible'] ?? true;

    if (p['sizes'] is List) {
      for (final s in ['S', 'M', 'L', 'XL']) {
        _sizes[s] = (p['sizes'] as List).contains(s);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _imageCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final selectedSizes = _sizes.entries.where((e) => e.value).map((e) => e.key).toList();

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'nombre': _nameCtrl.text.trim(),
      'category': _category,
      'categoria': _category,
      'price': num.tryParse(_priceCtrl.text.trim()) ?? _priceCtrl.text.trim(),
      'precio': num.tryParse(_priceCtrl.text.trim()) ?? _priceCtrl.text.trim(),
      'image': _imageCtrl.text.trim(),
      'imageUrl': _imageCtrl.text.trim(),
      'tag': _tagCtrl.text.trim(),
      'inStock': _inStock,
      'disponible': _inStock,
      'sizes': selectedSizes,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (widget.docId == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await widget.onSave(data, widget.docId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.docId != null;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'Editar Prenda' : 'Nueva Prenda de Catálogo',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _ink),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la prenda',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Ingresá el nombre' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Sacos', child: Text('Sacos')),
                          DropdownMenuItem(value: 'Pantalones', child: Text('Pantalones')),
                          DropdownMenuItem(value: 'Remeras', child: Text('Remeras')),
                          DropdownMenuItem(value: 'Vestidos', child: Text('Vestidos')),
                          DropdownMenuItem(value: 'Calzado', child: Text('Calzado')),
                          DropdownMenuItem(value: 'Accesorios', child: Text('Accesorios')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _category = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Precio (S/)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Ingresá el precio' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _imageCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL de Imagen (HTTPS)',
                    hintText: 'https://images.unsplash.com/...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _tagCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Etiqueta promocional',
                    hintText: 'Nuevo, Exclusivo, Oferta',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Talles disponibles:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _ink)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  children: _sizes.keys.map((size) {
                    final checked = _sizes[size] ?? false;
                    return FilterChip(
                      label: Text(size),
                      selected: checked,
                      onSelected: (val) => setState(() => _sizes[size] = val),
                      selectedColor: _lime,
                      checkmarkColor: _ink,
                      labelStyle: TextStyle(
                        color: _ink,
                        fontWeight: checked ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Disponible para venta inmediata (Stock Activo)', style: TextStyle(fontSize: 14)),
                  value: _inStock,
                  activeThumbColor: _ink,
                  activeTrackColor: _lime,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _inStock = val),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(isEdit ? 'Guardar Cambios' : 'Publicar Prenda', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
