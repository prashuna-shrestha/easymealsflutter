import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'webViewPage.dart';

class SubscriptionPage extends StatefulWidget {
  final int userId; // Accept userId

  const SubscriptionPage({super.key, required this.userId});

  @override
  _SubscriptionPageState createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  int? _subscribedPlanId;
  bool _isLoading = false; // Add loading state
  String?
      _subscriptionMessage; // Add message to display when subscription exists

  final String paymentUrl =
      "http://10.0.2.2/minoriiproject/initiate_subscription.php"; // Khalti payment URL

  @override
  void initState() {
    super.initState();
    _fetchUserSubscription();
  }

  // Fetch the current subscription status of the user
  Future<void> _fetchUserSubscription() async {
    final url = Uri.parse(
        'http://10.0.2.2/minoriiproject/subscription.php?user_id=${widget.userId}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success']) {
          setState(() {
            _subscribedPlanId = responseData['subscription_id'];
            _subscriptionMessage = null; // Clear previous messages
          });
        } else {
          setState(() {
            _subscribedPlanId = null; // User is not subscribed
            _subscriptionMessage = responseData['message']; // Display message
          });
        }
      }
    } catch (e) {
      print("Error fetching subscription: $e");
    }
  }

  // Subscribe user to a plan
  Future<void> _subscribeUser(String planName) async {
    if (_subscribedPlanId != null) {
      // Prevent user from subscribing to another plan if they are already subscribed
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are already subscribed to a plan.')),
      );
      return;
    }

    setState(() {
      _isLoading = true; // Show loading indicator
    });

    final subscriptionId = _getSubscriptionId(planName);
    final amount = _getPlanPrice(planName) * 100;

    // Step 1: Initiate Khalti payment
    try {
      final response = await http.post(
        Uri.parse(paymentUrl),
        body: {
          "amount": amount.toString(),
          "user_id": widget.userId.toString(),
          "email": "user@example.com", // Replace with actual user email
          "subscription_id": subscriptionId.toString(),
          "order_id": "SUB-${Random().nextInt(99999)}", // Unique order ID
        },
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (data['success'] == false && data['message'] != null) {
          // Show message if the user is already subscribed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'])),
          );
          setState(() {
            _isLoading = false; // Hide loading indicator
          });
          return;
        }

        if (data.containsKey('payment_url')) {
          final paymentUrl = data['payment_url'];
          final paymentId = data['payment_id']; // Get payment ID

          // Step 2: Navigate to WebViewPage for payment
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WebViewPage(paymentUrl: paymentUrl),
            ),
          ).then((_) async {
            // Step 3: After payment is completed, update payment status
            bool success = await _updatePaymentStatus(
                paymentId, "TRANSACTION_ID_FROM_KHALTI");

            if (success) {
              setState(() {
                _subscribedPlanId = subscriptionId; // Update UI
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Subscription successful!')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Subscription failed.')),
              );
            }
          });
        } else {
          print("Payment API Error: payment_url not found");
        }
      } else {
        print("Payment API error: HTTP ${response.statusCode}");
      }
    } catch (e) {
      print("Error during payment initiation: $e");
    } finally {
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
    }
  }

  // Update payment status after successful payment
  Future<bool> _updatePaymentStatus(int paymentId, String transactionId) async {
    final url = Uri.parse('http://10.0.2.2/minoriiproject/payment_success.php');

    try {
      final response = await http.post(
        url,
        body: {
          "payment_id": paymentId.toString(),
          "transaction_id": transactionId,
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['success'];
      } else {
        return false;
      }
    } catch (e) {
      print("Error: $e");
      return false;
    }
  }

  // Get subscription ID based on the plan name
  int _getSubscriptionId(String planName) {
    switch (planName) {
      case "Basic":
        return 1;
      case "Premium":
        return 2;
      case "Custom":
        return 3;
      default:
        return 0;
    }
  }

  // Get plan price based on the plan name
  double _getPlanPrice(String planName) {
    switch (planName) {
      case "Basic":
        return 4000;
      case "Premium":
        return 5000;
      case "Custom":
        return 6000;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription Plans')),
      body: Stack(
        children: [
          ListView(
            children: [
              if (_subscriptionMessage != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _subscriptionMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              SubscriptionCard(
                planName: "Basic",
                price: 4000,
                mealsPerMonth: 20,
                sweets: 0,
                drinks: 0,
                isSubscribed: _subscribedPlanId == 1,
                onSubscribe: () => _subscribeUser("Basic"),
                isAlreadySubscribed: _subscribedPlanId != null,
              ),
              SubscriptionCard(
                planName: "Premium",
                price: 5000,
                mealsPerMonth: 29,
                sweets: 0,
                drinks: 0,
                isSubscribed: _subscribedPlanId == 2,onSubscribe: () => _subscribeUser("Premium"),
                isAlreadySubscribed: _subscribedPlanId != null,
              ),
              SubscriptionCard(
                planName: "Custom",
                price: 6000,
                mealsPerMonth: 35,
                sweets: 2,
                drinks: 3,
                isSubscribed: _subscribedPlanId == 3,
                onSubscribe: () => _subscribeUser("Custom"),
                isAlreadySubscribed: _subscribedPlanId != null,
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

class SubscriptionCard extends StatelessWidget {
  final String planName;
  final double price;
  final int mealsPerMonth;
  final int sweets;
  final int drinks;
  final bool isSubscribed;
  final bool isAlreadySubscribed;
  final VoidCallback onSubscribe;

  const SubscriptionCard({
    super.key,
    required this.planName,
    required this.price,
    required this.mealsPerMonth,
    required this.sweets,
    required this.drinks,
    required this.isSubscribed,
    required this.isAlreadySubscribed,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: ListTile(
        title: Text(
          planName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text("Price: \$${price.toString()} per month\n"
            "Meals: $mealsPerMonth meals/month\n"
            "Sweets: $sweets\nDrinks: $drinks"),
        trailing: ElevatedButton(
          onPressed: isAlreadySubscribed
              ? null
              : onSubscribe, // Disable if already subscribed
          style: ElevatedButton.styleFrom(
            backgroundColor: isAlreadySubscribed ? Colors.grey : Colors.yellow,
          ),
          child: Text(
            isSubscribed ? 'Already Subscribed' : 'Subscribe',
            style: const TextStyle(color: Colors.black),
          ),
        ),
      ),
    );
  }
}
