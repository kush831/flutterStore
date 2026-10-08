import '../../../core/network/json_reader.dart';

class MembershipPlan {
  const MembershipPlan({
    required this.id,
    this.title = '',
    this.name = '',
    this.price = '',
    this.period = '',
    this.orders = 0,
    this.description = '',
    this.maxAmount = '',
    this.active = false,
  });

  final String id;
  final String title; // plan_title
  final String name; // plan_name
  final String price;
  final String period; // the number of days, as text
  final int orders;
  final String description;
  final String maxAmount;
  final bool active; // the store is on this plan now

  String get heading => title.isNotEmpty ? title : (name.isNotEmpty ? name : '');

  /// A plan without a limit has nothing to show for "max order value".
  bool get hasMaxAmount => !RegExp(r'^[0\s.,]*$').hasMatch(maxAmount);

  factory MembershipPlan.fromJson(JsonReader r) => MembershipPlan(
    id: r.text('id'),
    title: r.text('planTitle'),
    name: r.text('planName'),
    price: r.text('price'),
    period: r.text('period'),
    orders: r.integer('numberOfOrder') ?? 0,
    description: r.text('description'),
    maxAmount: r.text('maxAmountValid'),
    active: r.flag('isActive'),
  );
}

class PaymentOption {
  const PaymentOption({required this.id, this.name = '', this.icon = ''});

  final String id;
  final String name;
  final String icon;

  factory PaymentOption.fromJson(JsonReader r) => PaymentOption(id: r.text('paymentMethodId'), name: r.text('paymentMethod'), icon: r.text('icon'));
}

class MembershipData {
  const MembershipData({this.plans = const [], this.options = const []});

  final List<MembershipPlan> plans;
  final List<PaymentOption> options;

  factory MembershipData.fromJson(JsonReader root) {
    final d = root.sub('data');
    return MembershipData(
      plans: [for (final p in d.list('plans', MembershipPlan.fromJson)) if (p.id.isNotEmpty) p],
      options: [for (final o in d.list('paymentOption', PaymentOption.fromJson)) if (o.id.isNotEmpty) o],
    );
  }
}