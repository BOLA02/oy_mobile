import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/cta_button.dart';
import '../../../shared/widgets/ui.dart';
import '../application/rider_providers.dart';
import '../domain/wallet.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key, this.now});

  /// Injectable clock so the "today" and "this week" figures can be tested.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    final clock = now ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: wallet.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            Skeleton(height: 170, radius: AppRadius.lg),
            SizedBox(height: 16),
            Row(children: [Expanded(child: Skeleton(height: 84, radius: AppRadius.lg)), SizedBox(width: 12), Expanded(child: Skeleton(height: 84, radius: AppRadius.lg))]),
            SizedBox(height: 16),
            Skeleton(height: 170, radius: AppRadius.lg),
          ],
        ),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(walletProvider)),
        data: (w) => RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(walletProvider);
            await ref.read(walletProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              _BalanceCard(wallet: w),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _StatCard(label: 'Today', value: formatNaira(w.today(clock)))),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(label: 'This week', value: formatNaira(w.thisWeek(clock)))),
                ],
              ),
              const SizedBox(height: 14),
              _WeekChart(days: w.lastSevenDays(clock), today: clock),
              const SizedBox(height: 14),
              _BankCard(wallet: w),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 26, 4, 12),
                child: Text('Transactions', style: Theme.of(context).textTheme.titleLarge),
              ),
              if (w.transactions.isEmpty)
                const SurfaceCard(
                  child: EmptyView(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'No transactions yet',
                    subtitle: 'Your earnings and withdrawals will appear here.',
                  ),
                )
              else
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < w.transactions.length; i++) ...[
                        if (i > 0) const Divider(indent: 72, endIndent: 16),
                        _TxTile(tx: w.transactions[i]),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({required this.wallet});

  final WalletSummary wallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = wallet.withdrawBlockedReason;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Available balance', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(formatNaira(wallet.balance), style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.white, fontSize: 40)),
          if (wallet.pendingPayouts > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule_rounded, size: 14, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text('${formatNaira(wallet.pendingPayouts)} on its way to your bank',
                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          CtaButton(label: 'Withdraw', onPressed: wallet.canWithdraw ? () => _withdraw(context, ref) : null),
          if (blocked != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(blocked, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5)),
            ),
        ],
      ),
    );
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true, // cover the tab bar, like every other sheet
      builder: (_) => _WithdrawSheet(wallet: wallet),
    );
    if (message == null || !context.mounted) return;
    ref.invalidate(walletProvider);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 40),
        title: const Text('Withdrawal requested'),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
      ),
    );
  }
}

class _WithdrawSheet extends ConsumerStatefulWidget {
  const _WithdrawSheet({required this.wallet});

  final WalletSummary wallet;

  @override
  ConsumerState<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends ConsumerState<_WithdrawSheet> {
  final _amount = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? get _value => double.tryParse(_amount.text.replaceAll(',', '').trim());

  Future<void> _submit() async {
    final v = _value;
    if (v == null || v <= 0) {
      setState(() => _error = 'Enter an amount.');
      return;
    }
    if (v > widget.wallet.balance) {
      setState(() => _error = 'That is more than your available balance of ${formatNaira(widget.wallet.balance)}.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final message = await ref.read(riderRepositoryProvider).requestPayout(v);
      if (mounted) Navigator.pop(context, message);
    } on ApiException catch (e) {
      // The server explains itself (minimum balance, unverified account, ...).
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Withdraw to your bank', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('Available: ${formatNaira(widget.wallet.balance)}', style: const TextStyle(color: AppColors.inkMuted)),
              const SizedBox(height: 16),
              TextField(
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                decoration: const InputDecoration(prefixText: '₦ ', labelText: 'Amount'),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ActionChip(
                    backgroundColor: AppColors.primarySoft,
                    labelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                    avatar: const Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppColors.primary),
                    label: const Text('Withdraw all'),
                    onPressed: () => setState(() => _amount.text = widget.wallet.balance.round().toString()),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Payouts need a minimum balance and are sent to your verified bank account by our team.',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 12.5, height: 1.4),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                ),
              ],
              const SizedBox(height: 18),
              CtaButton(label: 'Request payout', loading: _busy, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.inkMuted)),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

/// Seven bars, one per day, today highlighted. Drawn by hand: a chart package
/// would be overkill for this.
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.days, required this.today});

  final List<DayEarning> days;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final max = days.fold<double>(0, (m, d) => d.amount > m ? d.amount : m);
    final total = days.fold<double>(0, (s, d) => s + d.amount);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Last 7 days', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const Spacer(),
              Text(formatNaira(total), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.success)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in days)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: max == 0 ? 0 : d.amount / max),
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOutCubic,
                                builder: (_, f, _) => Container(
                                  height: 6 + 74 * f,
                                  decoration: BoxDecoration(
                                    color: d.day.day == today.day && d.day.month == today.month
                                        ? AppColors.primary
                                        : d.amount > 0
                                            ? AppColors.primaryMid.withValues(alpha: 0.45)
                                            : AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(DateFormat('E').format(d.day).substring(0, 1),
                              style: const TextStyle(color: AppColors.inkMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BankCard extends StatelessWidget {
  const _BankCard({required this.wallet});

  final WalletSummary wallet;

  @override
  Widget build(BuildContext context) {
    final ok = wallet.hasBankDetails;
    final pendingVerification = !ok && !wallet.linkedBankAccount.startsWith('Not setup') && wallet.linkedBankAccount.isNotEmpty;
    return SurfaceCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: ok ? AppColors.successSoft : AppColors.cream,
            child: Icon(Icons.account_balance_rounded, color: ok ? AppColors.success : AppColors.warning),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Payout account', style: TextStyle(color: AppColors.inkMuted, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  wallet.linkedBankAccount.isEmpty ? 'Not set up' : wallet.linkedBankAccount,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (!ok)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      pendingVerification ? 'Waiting for verification' : 'Contact support to add your bank account',
                      style: const TextStyle(color: AppColors.warning, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          if (ok) const StatusPill(label: 'Verified', color: AppColors.success, background: AppColors.successSoft),
        ],
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({required this.tx});

  final WalletTx tx;

  @override
  Widget build(BuildContext context) {
    final credit = tx.type == TxType.credit;
    final failed = tx.status == TxStatus.failed;
    final color = failed ? AppColors.danger : (credit ? AppColors.success : AppColors.ink);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: credit ? AppColors.successSoft : AppColors.primarySoft,
        child: Icon(credit ? Icons.south_west_rounded : Icons.north_east_rounded, color: credit ? AppColors.success : AppColors.primary, size: 20),
      ),
      title: Text(tx.description.isEmpty ? (credit ? 'Earning' : 'Withdrawal') : tx.description,
          maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(DateFormat('d MMM, h:mm a').format(tx.createdAt)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('${credit ? '+' : '−'}${formatNaira(tx.amount)}',
              style: TextStyle(fontWeight: FontWeight.w800, color: color, decoration: failed ? TextDecoration.lineThrough : null)),
          if (tx.status != TxStatus.completed)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(failed ? 'Failed' : 'Pending',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: failed ? AppColors.danger : AppColors.warning)),
            ),
        ],
      ),
    );
  }
}
