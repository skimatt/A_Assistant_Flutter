import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../auth/login_page.dart';
import '../chat/chat_page.dart';
import '../finance/recap_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isHappy = false;
  final supabase = Supabase.instance.client;
  double _totalExpense = 0;
  List<Map<String, dynamic>> _recentTransactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // Fungsi untuk ambil data asli dari Supabase
  Future<void> _fetchData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Ambil total pengeluaran
      final transResponse = await supabase
          .from('transactions')
          .select('amount')
          .eq('user_id', user.id);

      double total = 0;
      for (var item in transResponse) {
        total += (item['amount'] as num).toDouble();
      }

      // Ambil 5 transaksi terbaru
      final recentResponse = await supabase
          .from('transactions')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(5);

      if (mounted) {
        setState(() {
          _totalExpense = total;
          _recentTransactions = List<Map<String, dynamic>>.from(recentResponse);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error Dashboard: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final String displayName = user?.email?.split('@')[0] ?? "User";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Halo,",
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            Text(
              displayName,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              LucideIcons.logOut,
              color: Colors.redAccent,
              size: 20,
            ),
            onPressed: () async {
              await supabase.auth.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (c) => const LoginPage()),
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBalanceCard(
                _totalExpense,
              ).animate().fadeIn().slideY(begin: 0.2),
              const SizedBox(height: 30),

              const Text(
                "Layanan Cepat",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),

              // GRID MENU (FIXED CLICKABLE)
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                children: [
                  _buildMenuIcon(
                    context,
                    LucideIcons.barChart2,
                    "Laporan",
                    Colors.purple,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RecapPage()),
                      );
                    },
                  ),
                  _buildMenuIcon(
                    context,
                    LucideIcons.wallet,
                    "Top Up",
                    Colors.orange,
                    () {},
                  ),
                  _buildMenuIcon(
                    context,
                    LucideIcons.send,
                    "Transfer",
                    Colors.blue,
                    () {},
                  ),
                  _buildMenuIcon(
                    context,
                    LucideIcons.layoutGrid,
                    "Lainnya",
                    Colors.teal,
                    () {},
                  ),
                ],
              ),

              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Aktivitas Terbaru",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RecapPage()),
                    ),
                    child: const Text("Lihat Semua"),
                  ),
                ],
              ),

              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_recentTransactions.isEmpty)
                const Center(child: Text("Belum ada transaksi"))
              else
                ..._recentTransactions
                    .map(
                      (item) => _buildTransactionItem(
                        item['description'] ?? "Transaksi",
                        DateFormat(
                          'dd MMM yyyy',
                        ).format(DateTime.parse(item['created_at'])),
                        "- Rp ${NumberFormat("#,###").format(item['amount'])}",
                        Colors.redAccent,
                      ),
                    )
                    .toList(),
            ],
          ),
        ),
      ),
      floatingActionButton: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => const ChatPage()),
        ),
        child:
            Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5C6BC0), Color(0xFF7E57C2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigo.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                      child: Icon(
                        _isHappy ? LucideIcons.bot : LucideIcons.bot,
                        // ekspresi “senyum” kita simulasi dengan animasi
                        key: ValueKey(_isHappy),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                )
                .animate(
                  onPlay: (controller) {
                    controller.repeat(reverse: true);
                    // toggle ekspresi tiap 2 detik
                    Future.doWhile(() async {
                      await Future.delayed(const Duration(seconds: 2));
                      if (!mounted) return false;
                      setState(() => _isHappy = !_isHappy);
                      return true;
                    });
                  },
                )
                // 🌱 muncul elastis
                .scale(
                  delay: 400.ms,
                  duration: 700.ms,
                  curve: Curves.elasticOut,
                )
                // 💓 napas hidup
                .then()
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.1, 1.1),
                  duration: 1200.ms,
                  curve: Curves.easeInOut,
                )
                // 😊 goyang kecil (kesan senyum / ramah)
                .then()
                .rotate(
                  begin: -0.05,
                  end: 0.05,
                  duration: 800.ms,
                  curve: Curves.easeInOut,
                ),
      ),
    );
  }

  Widget _buildBalanceCard(double amount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.indigo, Color(0xFF432C7B)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Total Pengeluaran",
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            "Rp ${NumberFormat("#,###").format(amount)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              Icon(LucideIcons.arrowUpRight, color: Colors.redAccent, size: 16),
              SizedBox(width: 5),
              Text(
                "Pengeluaran bulan ini",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuIcon(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      // Menambahkan Material agar efek InkWell muncul dan bisa diklik
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
    String title,
    String date,
    String amount,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey[100],
            child: const Icon(
              LucideIcons.shoppingBag,
              color: Colors.black54,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  date,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
