import '../widgets/project_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import 'quote_editor_page.dart';

class DashboardPage extends StatelessWidget {
  final void Function(int idx, {bool openCreate})? onNavigate;
  const DashboardPage({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B26),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A3045), width: 1),
            ),
            child: const TextField(
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search quotations',
                hintStyle: TextStyle(color: Color(0xFF8A92A6)),
                icon: Icon(Icons.search, color: Color(0xFF8A92A6)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _KpiRow(state: state),
          const SizedBox(height: 20),

          // ── Projects Overview ─────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle(context, 'Projects & QuickBook'),
              InkWell(
                onTap: () => onNavigate?.call(7),
                child: Text(
                  state.projects.isNotEmpty ? 'View all (${state.projects.length})' : 'Explore Projects',
                  style: const TextStyle(color: Color(0xFFFFC107), fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ProjectsDashboardSection(
            projects: state.projects.take(6).toList(),
            onNavigate: onNavigate,
          ),
          const SizedBox(height: 20),

          if (state.pinnedQuotes.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle(context, 'Pinned Quotations'),
                InkWell(
                  onTap: () => onNavigate?.call(1),
                  child: const Text('View all', style: TextStyle(color: Color(0xFFFFC107), fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _PinnedList(quotes: state.pinnedQuotes),
            const SizedBox(height: 24),
          ],
          isDesktop ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(context, 'Recent Quotations'),
                    const SizedBox(height: 10),
                    _RecentQuotesGrid(quotes: state.quotes.reversed.take(6).toList()),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(context, 'Activity'),
                    const SizedBox(height: 10),
                    _ActivityPanel(activities: state.activities),
                    const SizedBox(height: 16),
                    _sectionTitle(context, 'Revenue Overview'),
                    const SizedBox(height: 10),
                    _RevenueChart(state: state),
                  ],
                ),
              ),
            ],
          ) : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(context, 'Recent Quotations'),
              const SizedBox(height: 10),
              _RecentQuotesGrid(quotes: state.quotes.reversed.take(6).toList()),
              const SizedBox(height: 24),
              _sectionTitle(context, 'Activity'),
              const SizedBox(height: 10),
              _ActivityPanel(activities: state.activities),
              const SizedBox(height: 16),
              _sectionTitle(context, 'Revenue Overview'),
              const SizedBox(height: 10),
              _RevenueChart(state: state),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext ctx, String t) => Text(
    t,
    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(color: Colors.white),
  );
}


// â”€â”€ KPI Row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _KpiRow extends StatelessWidget {
  final AppState state;
  const _KpiRow({required this.state});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final kpis = [
      _kpi(context, 'QUOTATIONS THIS MONTH', '${state.totalQuotes}', null),
      _kpi(context, 'TOTAL APPROVED', '${state.approvedCount}', null),
      _kpi(context, 'PENDING APPROVALS', '${state.quotes.where((q) => q.status == QuoteStatus.pending).length}', null),
      _kpi(context, 'CONVERSION RATE', '${state.conversionRate.toStringAsFixed(0)}%', const Color(0xFFFFC107)),
    ];

    if (isDesktop) {
      return Row(children: [Expanded(child: kpis[0]), const SizedBox(width:16), Expanded(child: kpis[1]), const SizedBox(width:16), Expanded(child: kpis[2]), const SizedBox(width:16), Expanded(child: kpis[3])]);
    }
    
    return Column(
      children: [
        Row(children: [Expanded(child: kpis[0]), const SizedBox(width: 16), Expanded(child: kpis[1])]),
        const SizedBox(height: 16),
        Row(children: [Expanded(child: kpis[2]), const SizedBox(width: 16), Expanded(child: kpis[3])]),
      ],
    );
  }

  Widget _kpi(BuildContext ctx, String title, String value, Color? valueColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A3045), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: valueColor ?? Colors.white)),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Color(0xFF8A92A6), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
        ],
      ),
    );
  }
}

// â”€â”€ Quick Actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _QuickActions extends StatelessWidget {
  final void Function(int idx, {bool openCreate})? onNavigate;
  const _QuickActions({this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(context, Icons.business_center_rounded, 'Projects & QuickBook', const Color(0xFF38BDF8), () => onNavigate?.call(7)),
          const SizedBox(width: 12),
          _chip(context, Icons.star, 'New Quotation', const Color(0xFFFFC107), () => onNavigate?.call(1, openCreate: true)),
          const SizedBox(width: 12),
          _chip(context, Icons.receipt_long, 'Invoices', const Color(0xFF10B981), () => onNavigate?.call(4)),
          const SizedBox(width: 12),
          _chip(context, Icons.person, 'New Client', const Color(0xFF3B82F6), () => onNavigate?.call(2, openCreate: true)),
          const SizedBox(width: 12),
          _chip(context, Icons.inventory_2, 'New Product', const Color(0xFFE2A45C), () => onNavigate?.call(3, openCreate: true)),
        ],
      ),
    );
  }

  Widget _chip(BuildContext ctx, IconData icon, String label, Color iconColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF161B26),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A3045), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}


// â”€â”€ Pinned List â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _PinnedList extends StatelessWidget {
  final List<Quote> quotes;
  const _PinnedList({required this.quotes});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: quotes.map((q) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Builder(builder: (ctx) => InkWell(
          onTap: () {
            final appState = AppStateProvider.of(ctx);
            openQuoteEditorPage(ctx, appState, quote: q);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B26),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A3045), width: 1),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quote #${q.id}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('Client: ${q.clientName}', style: const TextStyle(color: Color(0xFF8A92A6), fontSize: 14)),
                      ],
                    ),
                    const Icon(Icons.star, color: Color(0xFFFFC107), size: 20),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF2A3045), height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Amount', style: TextStyle(color: Color(0xFF8A92A6), fontSize: 13)),
                    Text('KES ${q.total.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ],
            ),
          ),
        ),
        ),
      )).toList(),
    );
  }
}

// ── Recent Quotes Grid ────────────────────────────────────────────────────────

class _RecentQuotesGrid extends StatelessWidget {
  final List<Quote> quotes;
  const _RecentQuotesGrid({required this.quotes});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: quotes.length,
      itemBuilder: (ctx, i) {
        final q = quotes[i];
        return InkWell(
          onTap: () {
            final appState = AppStateProvider.of(ctx);
            openQuoteEditorPage(ctx, appState, quote: q);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161B26),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A3045)),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        q.id,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(label: q.status.label, color: q.status.color),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  q.clientName,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'KES ${q.total.toStringAsFixed(0)}',
                        style: const TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${q.date.day}/${q.date.month}/${q.date.year}',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// â”€â”€ Activity Panel â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ActivityPanel extends StatelessWidget {
  final List<ActivityEntry> activities;
  const _ActivityPanel({required this.activities});

  static String _relative(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    if (d.inDays < 7) return '${d.inDays} d ago';
    return DateFormat('dd MMM yyyy').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final items = activities.take(6).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A3045), width: 1),
      ),
      child: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No activity yet. Create a quote, client or project to see it here.',
                  style: TextStyle(color: Color(0xFF8A92A6), fontSize: 13)),
            )
          : Column(
              children: items.asMap().entries.map((e) {
                final isLast = e.key == items.length - 1;
                final item = e.value;
                final color = item.type.color;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 26, height: 26,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.18)),
                          child: Icon(item.type.icon, size: 14, color: color),
                        ),
                        if (!isLast) Container(
                          width: 2, height: 30,
                          color: const Color(0xFF2A3045),
                          margin: const EdgeInsets.only(top: 4),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text(_relative(item.timestamp), style: const TextStyle(color: Color(0xFF8A92A6), fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
    );
  }
}

// â”€â”€ Revenue Chart (CustomPaint bar chart) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _RevenueChart extends StatelessWidget {
  final AppState state;
  const _RevenueChart({required this.state});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF131B2F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _legend(Colors.green, 'Paid'),
                const SizedBox(width: 12),
                _legend(const Color(0xFFFFC107), 'Approved'),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 120,
              child: CustomPaint(
                painter: _BarChartPainter(state),
                size: const Size(double.infinity, 120),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color c, String label) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    ]);
  }
}

class _BarChartPainter extends CustomPainter {
  final AppState state;
  _BarChartPainter(this.state);

  @override
  void paint(Canvas canvas, Size size) {
    final approved = state.totalRevenue;
    final paid = state.paidRevenue;
    final max = approved == 0 ? 1 : approved;
    final barW = size.width / 5;
    final goldPaint = Paint()..color = const Color(0xFFFFC107);
    final greenPaint = Paint()..color = Colors.green;
    final bgPaint = Paint()..color = Colors.white.withValues(alpha: 0.05);

    // Background bars
    for (var i = 0; i < 2; i++) {
      final x = i * (barW + 16) + 8;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 0, barW, size.height), const Radius.circular(6)), bgPaint);
    }

    // Approved bar
    final approvedH = (approved / max) * size.height;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(8, size.height - approvedH, barW, approvedH), const Radius.circular(6)), goldPaint);

    // Paid bar
    final paidH = (paid / max) * size.height;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(barW + 24, size.height - paidH, barW, paidH), const Radius.circular(6)), greenPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// â”€â”€ Shared status badge â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Projects Dashboard Section ───────────────────────────────────────────────

class _ProjectsDashboardSection extends StatelessWidget {
  final List<Project> projects;
  final void Function(int idx, {bool openCreate})? onNavigate;

  const _ProjectsDashboardSection({required this.projects, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161B26),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A3045)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC107).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.business_center_rounded, color: Color(0xFFFFC107), size: 24),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No Projects Created Yet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  SizedBox(height: 2),
                  Text('Organize quotes, invoices, and expenses inside project workbooks.', style: TextStyle(color: Color(0xFF8A92A6), fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () => onNavigate?.call(7, openCreate: true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              child: const Text('New Project', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      );
    }


    return SizedBox(
      height: 272,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: projects.length,
        itemBuilder: (ctx, i) {
          final p = projects[i];
          return SizedBox(
            width: 300,
            child: ProjectCard(
              project: p,
              appState: AppStateProvider.of(ctx),
              compact: true,
              margin: EdgeInsets.only(right: i == projects.length - 1 ? 0 : 14),
            ),
          );
        },
      ),
    );
  }
}
