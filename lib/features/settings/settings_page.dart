import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  bool _isUploading = false;
  String? _avatarUrl;
  bool _isDarkMode = false; // Mock data untuk tema

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      setState(() {
        _nameController.text =
            user.userMetadata?['full_name'] ?? user.email!.split('@')[0];
        _avatarUrl = user.userMetadata?['avatar_url'];
      });
    }
  }

  // --- LOGIC: UPLOAD FOTO KE SUPABASE STORAGE ---
  Future<void> _updateAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final file = File(image.path);
      final user = supabase.auth.currentUser;
      final fileName = '${user!.id}/avatar.png';

      // Upload ke bucket 'avatars'
      await supabase.storage
          .from('avatars')
          .upload(fileName, file, fileOptions: const FileOptions(upsert: true));

      // Ambil Public URL
      final String publicUrl = supabase.storage
          .from('avatars')
          .getPublicUrl(fileName);

      // Update Metadata User
      await supabase.auth.updateUser(
        UserAttributes(data: {'avatar_url': publicUrl}),
      );

      setState(() => _avatarUrl = publicUrl);

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Foto profil diperbarui!")),
        );
    } catch (e) {
      debugPrint("Upload error: $e");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // --- LOGIC: UPDATE NAMA ---
  Future<void> _saveProfile() async {
    try {
      await supabase.auth.updateUser(
        UserAttributes(data: {'full_name': _nameController.text.trim()}),
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profil berhasil disimpan!")),
        );
    } catch (e) {
      debugPrint("Save error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Pengaturan",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // PROFILE SECTION
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundColor: Colors.indigo.withOpacity(0.1),
                    backgroundImage: _avatarUrl != null
                        ? NetworkImage(_avatarUrl!)
                        : null,
                    child: _avatarUrl == null
                        ? const Icon(
                            LucideIcons.user,
                            size: 50,
                            color: Colors.indigo,
                          )
                        : null,
                  ),
                  if (_isUploading)
                    const Positioned.fill(
                      child: CircularProgressIndicator(color: Colors.indigo),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _updateAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.indigo,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.camera,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().scale(),

            const SizedBox(height: 32),

            // FORM SECTION
            _buildSectionTitle("Informasi Profil"),
            const SizedBox(height: 12),
            _buildCard([
              _buildTextField(
                "Nama Lengkap",
                _nameController,
                LucideIcons.user,
              ),
              const Divider(height: 1),
              _buildListTile(
                "Email",
                supabase.auth.currentUser?.email ?? "",
                LucideIcons.mail,
                trailing: const SizedBox(),
              ),
            ]),

            const SizedBox(height: 32),

            _buildSectionTitle("Personalisasi"),
            const SizedBox(height: 12),
            _buildCard([
              _buildListTile(
                "Mode Gelap",
                _isDarkMode ? "On" : "Off",
                LucideIcons.moon,
                trailing: Switch(
                  value: _isDarkMode,
                  onChanged: (val) => setState(() => _isDarkMode = val),
                  activeColor: Colors.indigo,
                ),
              ),
              const Divider(height: 1),
              _buildListTile("Bahasa", "Indonesia", LucideIcons.languages),
            ]),

            const SizedBox(height: 40),

            // SAVE BUTTON
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: _saveProfile,
                child: const Text(
                  "Simpan Perubahan",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.indigo, size: 20),
      title: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: label,
          border: InputBorder.none,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildListTile(
    String title,
    String value,
    IconData icon, {
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.indigo, size: 20),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing:
          trailing ??
          const Icon(LucideIcons.chevronRight, size: 18, color: Colors.grey),
    );
  }
}
