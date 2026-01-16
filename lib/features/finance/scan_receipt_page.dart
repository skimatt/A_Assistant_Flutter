import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // kIsWeb

class ScanReceiptPage extends StatefulWidget {
  const ScanReceiptPage({super.key});

  @override
  State<ScanReceiptPage> createState() => _ScanReceiptPageState();
}

class _ScanReceiptPageState extends State<ScanReceiptPage> {
  File? _imageFile; // Android / iOS
  Uint8List? _webImage; // Web
  bool _isProcessing = false;
  final _picker = ImagePicker();

  // Warna Aksen Utama (Sama dengan ChatPage)
  final Color _accentColor = const Color(0xFF6366F1);
  final Color _bgBase = const Color(0xFFF8FAFC);

  // 1. Ambil Gambar
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 60, // Kompres sedikit agar upload cepat
    );
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _webImage = bytes;
          _imageFile = null;
        });
      } else {
        setState(() {
          _imageFile = File(pickedFile.path);
          _webImage = null;
        });
      }
      _processReceipt(); // Auto-start processing
    }
  }

  // 2. Kirim ke AI Vision
  Future<void> _processReceipt() async {
    if (_imageFile == null && _webImage == null) return;
    setState(() => _isProcessing = true);

    try {
      final bytes = kIsWeb ? _webImage! : await _imageFile!.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Prompt dioptimalkan untuk output JSON murni
      final response = await http.post(
        Uri.parse('https://skimatt.rahmatyoung10.workers.dev/'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "model": "google/gemini-2.0-flash-001",
          "messages": [
            {
              "role": "user",
              "content": [
                {
                  "type": "text",
                  "text":
                      "Analisis struk ini. Ambil Total Bayar, Nama Toko, dan Kategori. Output WAJIB JSON murni tanpa markdown: {\"amount\": 0, \"store\": \"Nama Toko\", \"category\": \"Lainnya\"}. Kategori pilih: Makan, Belanja, Transport, Tagihan, Lainnya.",
                },
                {
                  "type": "image_url",
                  "image_url": {"url": "data:image/jpeg;base64,$base64Image"},
                },
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String aiText = data['choices'][0]['message']['content'];

        // PEMBERSIH RESPONS: Hapus markdown ```json dan ```
        aiText = aiText.replaceAll(RegExp(r'```json|```'), '').trim();

        // Cari kurung kurawal pertama dan terakhir untuk memastikan JSON valid
        final startIndex = aiText.indexOf('{');
        final endIndex = aiText.lastIndexOf('}');

        if (startIndex != -1 && endIndex != -1) {
          aiText = aiText.substring(startIndex, endIndex + 1);
          final Map<String, dynamic> result = jsonDecode(aiText);
          if (mounted) _showConfirmationDialog(result);
        } else {
          throw Exception("Format JSON tidak ditemukan");
        }
      }
    } catch (e) {
      debugPrint("Error Scan: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal membaca struk. Coba lagi.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // 3. Simpan ke Database (Logika ChatPage)
  Future<void> _saveToDatabase(
    double amount,
    String category,
    String store,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.from('transactions').insert({
        'user_id': user.id,
        'amount': amount,
        'category': category,
        'description': store.isNotEmpty ? store : "Scan Struk",
        // 'date': DateTime.now().toIso8601String(), // Optional jika tabel ada default now()
      });

      if (mounted) {
        Navigator.pop(context); // Tutup Dialog
        Navigator.pop(context); // Kembali ke Home

        // Tampilkan Snackbar Sukses Modern
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            elevation: 0,
            content: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E), // Dark Navy
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.checkCircle, color: Color(0xFF10B981)),
                  const SizedBox(width: 12),
                  const Text(
                    "Struk berhasil dicatat!",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("DB Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal menyimpan: $e")));
      }
    }
  }

  // 4. Dialog Konfirmasi Modern
  void _showConfirmationDialog(Map<String, dynamic> data) {
    // Parsing aman untuk angka
    double initAmount = 0;
    if (data['amount'] is num) {
      initAmount = (data['amount'] as num).toDouble();
    } else if (data['amount'] is String) {
      initAmount =
          double.tryParse(
            data['amount'].toString().replaceAll(',', '').replaceAll('.', ''),
          ) ??
          0;
    }

    final TextEditingController amountCtrl = TextEditingController(
      text: initAmount.toInt().toString(),
    );
    final TextEditingController storeCtrl = TextEditingController(
      text: data['store'] ?? "",
    );
    String selectedCategory = data['category'] ?? "Lainnya";

    // Validasi kategori agar sesuai dropdown
    const validCategories = [
      'Makan',
      'Belanja',
      'Transport',
      'Tagihan',
      'Lainnya',
    ];
    if (!validCategories.contains(selectedCategory)) {
      selectedCategory = 'Lainnya';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.receipt, color: _accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              "Konfirmasi Struk",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: storeCtrl,
                decoration: InputDecoration(
                  labelText: "Nama Toko",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(LucideIcons.store, size: 18),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Total (Rp)",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(LucideIcons.banknote, size: 18),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                items: validCategories
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => selectedCategory = val!,
                decoration: InputDecoration(
                  labelText: "Kategori",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(LucideIcons.tag, size: 18),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Batal", style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () => _saveToDatabase(
              double.tryParse(amountCtrl.text) ?? 0,
              selectedCategory,
              storeCtrl.text,
            ),
            child: const Text(
              "Simpan Transaksi",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Scan Struk",
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Preview Image Container
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.width * 1.1,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: (_imageFile == null && _webImage == null)
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _accentColor.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            LucideIcons.scanLine,
                            size: 40,
                            color: _accentColor.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Belum ada foto struk",
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: kIsWeb
                          ? Image.memory(_webImage!, fit: BoxFit.cover)
                          : Image.file(_imageFile!, fit: BoxFit.cover),
                    ),
            ),

            const SizedBox(height: 40),

            // Controls
            if (_isProcessing)
              Column(
                children: [
                  SizedBox(
                    height: 50,
                    width: 50,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: _accentColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "AI sedang membaca...",
                    style: TextStyle(
                      color: _accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ).animate().fadeIn()
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildActionButton(
                    "Kamera",
                    LucideIcons.camera,
                    () => _pickImage(ImageSource.camera),
                  ),
                  const SizedBox(width: 24),
                  _buildActionButton(
                    "Galeri",
                    LucideIcons.image,
                    () => _pickImage(ImageSource.gallery),
                  ),
                ],
              ).animate().slideY(begin: 0.2, end: 0, duration: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _accentColor.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: _accentColor, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
