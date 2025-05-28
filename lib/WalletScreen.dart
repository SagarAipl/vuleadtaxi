import 'package:flutter/material.dart';
import 'package:vuleadtaxi/constants.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double _totalBalance = 1250.75;
  double _todaysEarnings = 79.94;
  double _weeklyEarnings = 485.50;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text('Wallet', style: TextStyle(color: AppConstants.textColor, fontWeight: FontWeight.w600, fontSize: 20)),
        backgroundColor: AppConstants.backgroundColor,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(color: AppConstants.subtitleColor.withOpacity(0.2), height: 1),
        ),
        actions: [
          IconButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Transaction history feature coming soon!', style: TextStyle(color: AppConstants.textColor)), backgroundColor: AppConstants.accentColor),
            ),
            icon: Icon(Icons.history, color: AppConstants.textColor),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppConstants.accentColor, AppConstants.accentColor.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppConstants.subtitleColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Balance', style: TextStyle(color: AppConstants.subtitleColor, fontSize: 16)),
                  SizedBox(height: 8),
                  Text('\$${_totalBalance.toStringAsFixed(2)}', style: TextStyle(color: AppConstants.textColor, fontSize: 32, fontWeight: FontWeight.bold)),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _showWithdrawDialog,
                          style: ElevatedButton.styleFrom(backgroundColor: AppConstants.textColor, foregroundColor: AppConstants.accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: Text('Withdraw', style: TextStyle(color: AppConstants.accentColor)),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Add money feature coming soon!', style: TextStyle(color: AppConstants.textColor)), backgroundColor: AppConstants.accentColor),
                          ),
                          style: ElevatedButton.styleFrom(backgroundColor: AppConstants.textColor.withOpacity(0.2), foregroundColor: AppConstants.textColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: Text('Add Money', style: TextStyle(color: AppConstants.textColor)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _buildEarningsCard('Today\'s Earnings', '\$${_todaysEarnings.toStringAsFixed(2)}', Icons.today, AppConstants.accentColor)),
                  SizedBox(width: 16),
                  Expanded(child: _buildEarningsCard('Weekly Earnings', '\$${_weeklyEarnings.toStringAsFixed(2)}', Icons.calendar_view_week, AppConstants.accentColor)),
                ],
              ),
            ),
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppConstants.backgroundColor.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppConstants.subtitleColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.textColor)),
                  SizedBox(height: 16),
                  _buildTransactionItem('Trip Payment', '+\$25.50', 'Today, 2:30 PM', true),
                  _buildTransactionItem('Trip Payment', '+\$18.75', 'Today, 1:15 PM', true),
                  _buildTransactionItem('Withdrawal', '-\$100.00', 'Yesterday, 3:45 PM', false),
                  _buildTransactionItem('Trip Payment', '+\$32.25', 'Yesterday, 11:20 AM', true),
                  _buildTransactionItem('Trip Payment', '+\$15.80', 'Yesterday, 9:45 AM', true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsCard(String title, String amount, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.backgroundColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.subtitleColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 12),
          Text(amount, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppConstants.textColor)),
          SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: AppConstants.subtitleColor)),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(String title, String amount, String time, bool isCredit) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(color: isCredit ? AppConstants.accentColor.withOpacity(0.2) : Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward, color: isCredit ? AppConstants.accentColor : Colors.red, size: 16),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: AppConstants.textColor)),
                Text(time, style: TextStyle(fontSize: 12, color: AppConstants.subtitleColor)),
              ],
            ),
          ),
          Text(amount, style: TextStyle(fontWeight: FontWeight.bold, color: isCredit ? AppConstants.accentColor : Colors.red)),
        ],
      ),
    );
  }

  void _showWithdrawDialog() {
    final TextEditingController amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.backgroundColor,
        title: Text('Withdraw Money', style: TextStyle(color: AppConstants.textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Available Balance: \$${_totalBalance.toStringAsFixed(2)}', style: TextStyle(color: AppConstants.subtitleColor)),
            SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount to withdraw',
                labelStyle: TextStyle(color: AppConstants.subtitleColor),
                prefixText: '\$',
                prefixStyle: TextStyle(color: AppConstants.textColor),
                border: OutlineInputBorder(borderSide: BorderSide(color: AppConstants.subtitleColor.withOpacity(0.3))),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppConstants.subtitleColor.withOpacity(0.3))),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppConstants.accentColor)),
              ),
              style: TextStyle(color: AppConstants.textColor),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: AppConstants.skipButtonColor))),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0 && amount <= _totalBalance) {
                setState(() => _totalBalance -= amount);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Withdrawal of \$${amount.toStringAsFixed(2)} initiated!', style: TextStyle(color: AppConstants.textColor)), backgroundColor: AppConstants.accentColor),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter a valid amount', style: TextStyle(color: AppConstants.textColor)), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Withdraw', style: TextStyle(color: AppConstants.textColor)),
          ),
        ],
      ),
    );
  }
}