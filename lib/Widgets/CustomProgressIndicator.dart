import 'package:flutter/material.dart';

class CustomProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> stepTitles;

  const CustomProgressIndicator({
    Key? key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepTitles,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const Text(
            'Create Your Profile',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: List.generate(totalSteps, (index) {
              return Expanded(
                child: Row(
                  children: [
                    _buildStepCircle(index),
                    if (index < totalSteps - 1) _buildConnector(index),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(totalSteps, (index) {
              return Expanded(
                child: Text(
                  stepTitles[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: index <= currentStep
                        ? const Color(0xFFE89D43)
                        : Colors.white.withOpacity(0.5),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int index) {
    final bool isCompleted = index < currentStep;
    final bool isCurrent = index == currentStep;
    final bool isUpcoming = index > currentStep;

    Color backgroundColor;
    Color borderColor;
    Widget child;

    if (isCompleted) {
      backgroundColor = const Color(0xFFE89D43);
      borderColor = const Color(0xFFE89D43);
      child = const Icon(
        Icons.check,
        color: Colors.white,
        size: 16,
      );
    } else if (isCurrent) {
      backgroundColor = const Color(0xFFE89D43);
      borderColor = const Color(0xFFE89D43);
      child = Text(
        '${index + 1}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      );
    } else {
      backgroundColor = Colors.transparent;
      borderColor = Colors.white.withOpacity(0.3);
      child = Text(
        '${index + 1}',
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      );
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: isCompleted || isCurrent
            ? [
          BoxShadow(
            color: const Color(0xFFE89D43).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ]
            : null,
      ),
      child: Center(child: child),
    );
  }

  Widget _buildConnector(int index) {
    final bool isCompleted = index < currentStep;

    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isCompleted
              ? const Color(0xFFE89D43)
              : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}