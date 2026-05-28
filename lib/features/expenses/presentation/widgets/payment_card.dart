import 'package:flutter/material.dart';

class PaymentCard extends StatelessWidget {
  const PaymentCard({
    super.key,
    required this.appName,
    required this.pricePerMonth,
    required this.daysLeft,
    this.isHighlighted = false,
    this.icon,
  });

  final String appName;
  final String pricePerMonth;
  final String daysLeft;
  final bool isHighlighted;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(20);
    final cardChild = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? Colors.white.withValues(alpha: 0.2)
                      : const Color(0xFFF1F3F7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon ?? Icons.apps_rounded,
                  size: 20,
                  color: isHighlighted
                      ? Colors.white
                      : const Color(0xFF252A3A),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.more_vert_rounded,
                color: isHighlighted
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.black54,
              ),
            ],
          ),
          const Spacer(),
          Text(
            appName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isHighlighted ? Colors.white : const Color(0xFF111827),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              text: pricePerMonth,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color:
                        isHighlighted ? Colors.white : const Color(0xFF111827),
                    fontWeight: FontWeight.bold,
                  ),
              children: <InlineSpan>[
                TextSpan(
                  text: '/month',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isHighlighted
                            ? Colors.white.withValues(alpha: 0.85)
                            : Colors.black54,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            daysLeft,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isHighlighted
                      ? Colors.white.withValues(alpha: 0.9)
                      : Colors.black54,
                ),
          ),
        ],
      ),
    );

    return Container(
      width: 180,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: isHighlighted
          ? DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF6E3EFF), Color(0xFF9A6BFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: cardChild,
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: borderRadius,
              ),
              child: cardChild,
            ),
    );
  }
}
