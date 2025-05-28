import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:vuleadtaxi/constants.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  List<dynamic> completedRides = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchRides();
  }

  Future<int?> _getDriverId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('u_id');
  }

  Future<void> _fetchRides() async {
    setState(() {
      isLoading = true;
    });

    try {
      final driverId = await _getDriverId();
      if (driverId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Driver ID not found', style: TextStyle(color: AppConstants.textColor))),
          );
        }
        setState(() {
          isLoading = false;
          completedRides = _getDummyRides();
        });
        return;
      }

      final response = await http.get(
        Uri.parse('https://vnumdemo.caxis.ca/public/api/rides'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> allRides = data['rides'] as List<dynamic>? ?? [];

        final List<dynamic> relevantRides = allRides.where((ride) {
          final nearbyDrivers = ride['nearby_drivers'] as List<dynamic>? ?? [];
          return nearbyDrivers.any((driver) {
            final driverUId = driver['U_Id'];
            if (driverUId is String) {
              return int.tryParse(driverUId) == driverId;
            } else if (driverUId is int) {
              return driverUId == driverId;
            }
            return false;
          });
        }).toList();

        setState(() {
          completedRides = relevantRides
              .where((ride) => ride['ride']?['status'] == 'completed')
              .toList();
          if (completedRides.isEmpty) {
            completedRides = _getDummyRides();
          }
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load rides: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching rides: $e', style: TextStyle(color: AppConstants.textColor))),
        );
      }
      setState(() {
        isLoading = false;
        completedRides = _getDummyRides();
      });
    }
  }

  List<dynamic> _getDummyRides() {
    return [
      {
        'ride': {
          'id': 1001,
          'user_id': 101,
          'pickup_location': 'New York City',
          'dropoff_location': 'Brooklyn',
          'total_fare': '15.50',
          'status': 'completed',
        },
      },
      {
        'ride': {
          'id': 1002,
          'user_id': 102,
          'pickup_location': 'Los Angeles',
          'dropoff_location': 'Santa Monica',
          'total_fare': '22.75',
          'status': 'completed',
        },
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Completed Bookings',
          style: TextStyle(
            color: AppConstants.textColor,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppConstants.backgroundColor,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppConstants.subtitleColor.withOpacity(0.2),
            height: 1,
          ),
        ),
      ),
      body: isLoading
          ? Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppConstants.accentColor),
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchRides,
        color: AppConstants.accentColor,
        child: completedRides.isEmpty
            ? Center(
          child: Text(
            'No completed bookings',
            style: TextStyle(
              fontSize: 16,
              color: AppConstants.subtitleColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: completedRides.length,
          itemBuilder: (context, index) {
            final ride = completedRides[index]['ride'] ?? {};
            return _buildBookingCard(
              bookingId: 'Booking #${ride['id'] ?? 'N/A'}',
              customerName: 'Customer ${ride['user_id'] ?? 'N/A'}',
              pickup: ride['pickup_location'] ?? 'N/A',
              dropoff: ride['dropoff_location'] ?? 'N/A',
              fare: '\$${ride['total_fare'] ?? '0.00'}',
              status: 'Completed',
              statusColor: AppConstants.accentColor,
              showActions: false,
              rideId: ride['id'] ?? 0,
            );
          },
        ),
      ),
    );
  }

  Widget _buildBookingCard({
    required String bookingId,
    required String customerName,
    required String pickup,
    required String dropoff,
    required String fare,
    required String status,
    required Color statusColor,
    required bool showActions,
    required int rideId,
  }) {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppConstants.backgroundColor.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppConstants.subtitleColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  bookingId,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppConstants.textColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.person,
              text: customerName,
              iconColor: AppConstants.subtitleColor,
            ),
            const SizedBox(height: 6),
            _buildInfoRow(
              icon: Icons.location_on,
              text: pickup,
              iconColor: AppConstants.accentColor,
            ),
            const SizedBox(height: 6),
            _buildInfoRow(
              icon: Icons.flag,
              text: dropoff,
              iconColor: AppConstants.accentColor,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Fare',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppConstants.subtitleColor,
                  ),
                ),
                Text(
                  fare,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppConstants.accentColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String text,
    required Color iconColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: iconColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: AppConstants.textColor,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}