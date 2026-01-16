import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui'; // Diperlukan untuk ImageFilter (Blur effect)

// Import page tetap sama sesuai logika asli
import '../chat/chat_page.dart';
import '../finance/recap_page.dart';
import '../finance/scan_receipt_page.dart';
import '../settings/settings_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final supabase = Supabase.instance.client;
  double _totalExpense = 0;
  List<Map<String, dynamic>> _recentTransactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Mengatur status bar agar transparan untuk tampilan immersive
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            Brightness.light, // Icon putih untuk background gelap
        statusBarBrightness: Brightness.dark, // iOS
      ),
    );
    _fetchDashboardData();
  }

  // --- LOGIKA ASLI (TIDAK DIUBAH) ---
  Future<void> _fetchDashboardData() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final transData = await supabase
          .from('transactions')
          .select('amount')
          .eq('user_id', userId);
      double total = transData.fold(
        0,
        (sum, item) => sum + (item['amount'] as num).toDouble(),
      );

      final recentData = await supabase
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(3);

      if (mounted) {
        setState(() {
          _totalExpense = total;
          _recentTransactions = List<Map<String, dynamic>>.from(recentData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final String displayName = user?.email?.split('@')[0] ?? "Sultan";

    // Palette Warna Premium (Refined)
    const Color bgBase = Color(0xFFF7F9FC); // Putih keabuan yang sangat bersih
    const Color accentColor = Color(0xFF6366F1); // Indigo modern

    return Scaffold(
      backgroundColor: bgBase,
      body: RefreshIndicator(
        onRefresh: _fetchDashboardData,
        color: accentColor,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // --- HERO SECTION ---
            SliverToBoxAdapter(
              child: _buildPremiumHero(displayName)
                  .animate()
                  .fadeIn(duration: 800.ms)
                  .slideY(begin: -0.1, end: 0, curve: Curves.easeOutQuart),
            ),

            // --- MENU & LIST SECTION ---
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 20),

                  // Label Menu
                  _buildSectionHeader("Akses Cepat", null),
                  const SizedBox(height: 16),

                  // Quick Menu Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildModernMenu(
                        context,
                        LucideIcons.scanLine,
                        "Scan",
                        const Color(0xFFFF8A65), // Soft Orange
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ScanReceiptPage(),
                          ),
                        ),
                      ).animate().fade().scale(delay: 100.ms),

                      _buildModernMenu(
                        context,
                        LucideIcons.messageSquare,
                        "Catat",
                        const Color(0xFF64B5F6), // Soft Blue
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ChatPage()),
                        ),
                      ).animate().fade().scale(delay: 200.ms),

                      _buildModernMenu(
                        context,
                        LucideIcons.pieChart,
                        "Analisis",
                        const Color(0xFFBA68C8), // Soft Purple
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RecapPage()),
                        ),
                      ).animate().fade().scale(delay: 300.ms),

                      _buildModernMenu(
                        context,
                        LucideIcons.slidersHorizontal,
                        "Setting",
                        const Color(0xFF4DB6AC), // Soft Teal
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsPage(),
                          ),
                        ),
                      ).animate().fade().scale(delay: 400.ms),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Header Aktivitas
                  _buildSectionHeader(
                    "Transaksi Terkini",
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RecapPage()),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // List Logic
                  if (_isLoading)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: accentColor.withOpacity(0.5),
                        ),
                      ),
                    )
                  else if (_recentTransactions.isEmpty)
                    _buildEmptyState()
                  else
                    Column(
                      children: _recentTransactions.asMap().entries.map((
                        entry,
                      ) {
                        int idx = entry.key;
                        var item = entry.value;
                        return _buildPremiumTransactionCard(item, idx);
                      }).toList(),
                    ),

                  const SizedBox(height: 120), // Spacer bawah
                ]),
              ),
            ),
          ],
        ),
      ),
      // --- FAB MODERN ---
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.4),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (c) => const ChatPage()),
          ),
          backgroundColor: accentColor,
          elevation: 0,
          highlightElevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          icon: const Icon(LucideIcons.sparkles, color: Colors.white, size: 20),
          label: const Text(
            "Tanya AI",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildPremiumHero(String name) {
    return Stack(
      children: [
        // 1. Background Gradient Mesh
        Container(
          height: 340,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF2E2E48),
                Color(0xFF1A1A2E),
              ], // Deep Midnight Blue
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
          ),
        ),

        // 2. Decorative Blobs (Lebih halus)
        Positioned(
          top: -60,
          right: -60,
          child:
              Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF6C63FF).withOpacity(0.15),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withOpacity(0.4),
                          blurRadius: 50,
                        ),
                      ],
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 1, end: 1.1, duration: 4.seconds),
        ),
        Positioned(
          bottom: 40,
          left: -40,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEC4899).withOpacity(0.1), // Pink hint
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEC4899).withOpacity(0.4),
                  blurRadius: 50,
                ),
              ],
            ),
          ),
        ),

        // 3. Konten Utama
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 68, 28, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Profil
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Selamat Datang,",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name.capitalize(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      child: const Icon(
                        LucideIcons.user,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 36),

              // Kartu Saldo Glassmorphism (Ultimate Version)
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1.5,
                      ),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.12),
                          Colors.white.withOpacity(0.02),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    LucideIcons.wallet,
                                    color: Colors.white70,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "Total Pengeluaran",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            // Badge kecil
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "Bulan Ini",
                                style: TextStyle(
                                  color: Color(0xFFFF8A80),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Rp ${NumberFormat("#,###", "id_ID").format(_totalExpense)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Separator line
                        Container(
                          height: 1,
                          width: double.infinity,
                          color: Colors.white.withOpacity(0.1),
                        ),
                        const SizedBox(height: 12),
                        const Row(
                          children: [
                            Icon(
                              LucideIcons.checkCircle2,
                              color: Color(0xFF69F0AE),
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Text(
                              "Data sinkron otomatis",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback? onAction) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E), // Dark Navy
              letterSpacing: -0.5,
            ),
          ),
          if (onAction != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        "Lihat Semua",
                        style: TextStyle(
                          color: Color(0xFF6366F1), // Indigo
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        LucideIcons.arrowRight,
                        size: 14,
                        color: Color(0xFF6366F1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModernMenu(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            splashColor: color.withOpacity(0.1),
            highlightColor: color.withOpacity(0.05),
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.withOpacity(0.05)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE0E5EC).withOpacity(0.6),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4A4A5A),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumTransactionCard(Map<String, dynamic> item, int index) {
    return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9EA3B0).withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    // Icon Bulat
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FC),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.receipt,
                          color: Color(0xFF6366F1), // Indigo
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),

                    // Info Transaksi
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['description'] ?? "Transaksi",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1A1A2E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                LucideIcons.clock,
                                size: 12,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('d MMM, HH:mm').format(
                                  DateTime.parse(item['created_at']).toLocal(),
                                ),
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Nominal
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "-Rp${NumberFormat("#,###", "id_ID").format(item['amount'])}",
                          style: const TextStyle(
                            color: Color(0xFFE53935), // Merah yang lebih soft
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: (100 * index).ms)
        .slideX(begin: 0.05, curve: Curves.easeOut);
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    LucideIcons.ghost,
                    color: Colors.grey.shade300,
                    size: 40,
                  ),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .slideY(
                  begin: 0,
                  end: -0.1,
                  duration: 2.seconds,
                  curve: Curves.easeInOut,
                ),

            const SizedBox(height: 24),
            Text(
              "Belum Ada Transaksi",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Transaksi hari ini akan muncul di sini.",
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// Extension kecil untuk kapitalisasi nama
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
