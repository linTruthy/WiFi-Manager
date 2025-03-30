import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../database/models/customer.dart';
import '../database/models/payment.dart';
import '../providers/customer_provider.dart';
import '../services/receipt_service.dart';

class ReceiptButton extends ConsumerStatefulWidget {
  final Payment payment;
  final bool isCompact;
  
  const ReceiptButton({
    super.key, 
    required this.payment,
    this.isCompact = true,
  });

  @override
  ConsumerState<ReceiptButton> createState() => _ReceiptButtonState();
}

class _ReceiptButtonState extends ConsumerState<ReceiptButton> {
  bool _isGenerating = false;
  bool _showTooltip = false;
  
  @override
  Widget build(BuildContext context) {
    final customerAsync = ref.watch(customerProvider(widget.payment.customerId));
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: 'Generate receipt for payment',
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.lightImpact();
          setState(() => _showTooltip = true);
          Future.delayed(Duration(seconds: 2), () {
            if (mounted) setState(() => _showTooltip = false);
          });
        },
        child: Stack(
          children: [
            widget.isCompact 
                ? _buildCompactButton(customerAsync, theme)
                : _buildFullButton(customerAsync, theme),
                
            // Tooltip
            if (_showTooltip)
              Positioned(
                bottom: widget.isCompact ? 40 : 50,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Generate Receipt',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCompactButton(
    AsyncValue<Customer?> customerAsync, 
    ThemeData theme
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleReceiptGeneration(customerAsync),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: _isGenerating 
              ? SizedBox(
                  width: 16, 
                  height: 16, 
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
  
  Widget _buildFullButton(
    AsyncValue<Customer?> customerAsync, 
    ThemeData theme
  ) {
    return ElevatedButton.icon(
      onPressed: () => _handleReceiptGeneration(customerAsync),
      icon: _isGenerating 
          ? SizedBox(
              width: 16, 
              height: 16, 
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(Icons.receipt_long),
      label: Text(_isGenerating ? 'Generating...' : 'Receipt'),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
  
  Future<void> _handleReceiptGeneration(AsyncValue<Customer?> customerAsync) async {
    // Only proceed if we're not already generating
    if (_isGenerating) return;
    
    setState(() => _isGenerating = true);
    
    try {
      await customerAsync.when(
        data: (customer) async {
          if (customer == null) {
            _showErrorSnackBar('Customer not found');
            return;
          }
          
          HapticFeedback.mediumImpact();
          await ReceiptService.generateAndShareReceipt(
            payment: widget.payment,
            customer: customer,
          );
        },
        loading: () {
          _showErrorSnackBar('Loading customer information...');
        },
        error: (error, _) {
          _showErrorSnackBar('Error: $error');
        },
      );
    } catch (e) {
      _showErrorSnackBar('Failed to generate receipt: $e');
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  
  void _showReceiptOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: Icon(Icons.share),
            title: Text('Share Receipt'),
            onTap: () {
              Navigator.pop(context);
              // Share receipt
            },
          ),
          ListTile(
            leading: Icon(Icons.download),
            title: Text('Download PDF'),
            onTap: () {
              Navigator.pop(context);
              // Download receipt
            },
          ),
          ListTile(
            leading: Icon(Icons.print),
            title: Text('Print Receipt'),
            onTap: () {
              Navigator.pop(context);
              // Print receipt
            },
          ),
        ],
      ),
    );
  }
}