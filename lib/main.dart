import 'package:flutter/material.dart';

void main() => runApp(const ShamsiApp());

// ---------- Colors ----------
const Color kNavy = Color(0xFF14213D);
const Color kCream = Color(0xFFF7F5EF);
const Color kOrange = Color(0xFFF2A541);
const Color kGrey = Color(0xFF4A5568);
const Color kLightGrey = Color(0xFFD5D9E2);
const Color kSoftText = Color(0xFFC9D1E0);

// ---------- Assumptions used in the calculation ----------
const double kPanelKwhPerDay = 1.8; // one 450 W panel gives about 1.8 kWh a day
const double kBatteryKwh = 2.4; // one 200Ah 12V battery stores about 2.4 kWh

// When the appliance is used
enum Usage { day, night, both }

// ---------- Model ----------
class Appliance {
  String name;
  int watts;
  int hours;
  int count;
  Usage usage;

  Appliance({
    required this.name,
    required this.watts,
    required this.hours,
    this.count = 1,
    this.usage = Usage.day,
  });

  // energy per day in kWh = watts × hours × count ÷ 1000
  double get kwh => watts * hours * count / 1000;
}

// ---------- App ----------
class ShamsiApp extends StatelessWidget {
  const ShamsiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shamsi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kNavy),
        scaffoldBackgroundColor: kCream,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Appliance> appliances = [
    Appliance(name: 'Water heater', watts: 1500, hours: 2, usage: Usage.day),
    Appliance(name: 'Fridge', watts: 150, hours: 24, usage: Usage.both),
    Appliance(name: 'TV', watts: 100, hours: 5, usage: Usage.night),
    Appliance(
      name: 'Lights',
      watts: 10,
      hours: 6,
      count: 6,
      usage: Usage.night,
    ),
  ];

  // results (null = not calculated yet)
  double? dayKwh;
  double? nightKwh;
  int? panels;
  int? batteries;

  // hide the old result whenever something changes
  void clearResult() {
    dayKwh = null;
    nightKwh = null;
    panels = null;
    batteries = null;
  }

  // ---------- LOGIC ----------
  void calculate() {
    double day = 0;
    double night = 0;

    for (final a in appliances) {
      switch (a.usage) {
        case Usage.day:
          day += a.kwh;
          break;
        case Usage.night:
          night += a.kwh;
          break;
        case Usage.both:
          day += a.kwh / 2;
          night += a.kwh / 2;
          break;
      }
    }

    if (day + night == 0) {
      setState(clearResult);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one appliance')),
      );
      return;
    }

    setState(() {
      dayKwh = day;
      nightKwh = night;
      // panels must cover the whole day: daytime use + charging the batteries
      panels = ((day + night) / kPanelKwhPerDay).ceil();
      // batteries only need to cover the night
      batteries = night == 0 ? 0 : (night / kBatteryKwh).ceil();
    });
  }

  // Day -> Night -> Both -> Day
  void nextUsage(Appliance a) {
    setState(() {
      a.usage = Usage.values[(a.usage.index + 1) % Usage.values.length];
      clearResult();
    });
  }

  // ---------- Add / edit dialog ----------
  Future<void> openDialog({Appliance? existing}) async {
    final nameC = TextEditingController(text: existing?.name ?? '');
    final wattsC = TextEditingController(
      text: existing?.watts.toString() ?? '',
    );
    final hoursC = TextEditingController(
      text: existing?.hours.toString() ?? '',
    );
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(
            existing == null ? 'Add appliance' : 'Edit ${existing.name}',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameC,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: wattsC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Power',
                  suffixText: 'W',
                ),
              ),
              TextField(
                controller: hoursC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Hours per day',
                  suffixText: 'h',
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final watts = int.tryParse(wattsC.text.trim());
                final hours = int.tryParse(hoursC.text.trim());
                if (nameC.text.trim().isEmpty ||
                    watts == null ||
                    watts <= 0 ||
                    hours == null ||
                    hours < 1 ||
                    hours > 24) {
                  setDialog(
                    () => error =
                        'Enter a name, watts above 0, and 1 to 24 hours',
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    final name = nameC.text.trim();
    final watts = int.parse(wattsC.text.trim());
    final hours = int.parse(hoursC.text.trim());

    setState(() {
      if (existing == null) {
        appliances.add(Appliance(name: name, watts: watts, hours: hours));
      } else {
        existing.name = name;
        existing.watts = watts;
        existing.hours = hours;
      }
      clearResult();
    });
  }

  // ---------- GUI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        title: const Text(
          '☀️ Shamsi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text('My home', style: TextStyle(color: kSoftText)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (appliances.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No appliances yet. Tap "Add appliance" to start.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kGrey),
                ),
              ),
            for (final a in appliances) applianceCard(a),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () => openDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add appliance'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kNavy,
                side: const BorderSide(color: kNavy),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: calculate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kOrange,
                  foregroundColor: kNavy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Calculate',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (panels != null) resultCard(),
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'Tap Day/Night to change it · Tap a name to edit · Swipe left to delete',
                textAlign: TextAlign.center,
                style: TextStyle(color: kGrey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget applianceCard(Appliance a) {
    return Dismissible(
      key: ObjectKey(a),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => setState(() {
        appliances.remove(a);
        clearResult();
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kLightGrey),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => openDialog(existing: a),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${a.watts} W · ${a.hours} h',
                          style: const TextStyle(fontSize: 13, color: kGrey),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, size: 14, color: kGrey),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            usagePill(a),
            const SizedBox(width: 4),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.remove),
              onPressed: a.count == 0
                  ? null
                  : () => setState(() {
                      a.count--;
                      clearResult();
                    }),
            ),
            Text(
              '${a.count}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add),
              onPressed: () => setState(() {
                a.count++;
                clearResult();
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget usagePill(Appliance a) {
    Color bg;
    Color fg;
    String label;
    switch (a.usage) {
      case Usage.day:
        bg = kOrange;
        fg = kNavy;
        label = 'Day';
        break;
      case Usage.night:
        bg = kNavy;
        fg = Colors.white;
        label = 'Night';
        break;
      case Usage.both:
        bg = kLightGrey;
        fg = kNavy;
        label = 'Both';
        break;
    }
    return GestureDetector(
      onTap: () => nextUsage(a),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget resultCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kNavy,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Day: ${dayKwh!.toStringAsFixed(2)} kWh from the panels',
            style: const TextStyle(color: kSoftText, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Night: ${nightKwh!.toStringAsFixed(2)} kWh from the batteries',
            style: const TextStyle(color: kSoftText, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: bigNumber(panels!, 'Panels')),
              Container(width: 1, height: 56, color: kSoftText),
              Expanded(child: bigNumber(batteries!, 'Batteries')),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Estimated result only',
            style: TextStyle(color: kSoftText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget bigNumber(int value, String label) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: kOrange,
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    );
  }
}
