import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../utils/constants.dart';

/// 喝水紀錄頁：輸入今天攝取多少水、目標攝取多少，並用一個大水滴圖示顯示進度。
class WaterScreen extends StatefulWidget {
  const WaterScreen({super.key});

  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends State<WaterScreen> {
  static const _defaultTargetMl = 2000;

  late final String _todayStr;
  int _consumedMl = 0;
  int _targetMl = _defaultTargetMl;
  late final TextEditingController _consumedCtrl;
  late final TextEditingController _targetCtrl;
  bool _loading = true;

  double get _progress =>
      _targetMl <= 0 ? 0 : (_consumedMl / _targetMl).clamp(0, 1).toDouble();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _todayStr = '${now.year}-${now.month}-${now.day}';
    _consumedCtrl = TextEditingController();
    _targetCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _consumedCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final entry = await DBHelper.instance.getWaterLog(_todayStr);
    int consumed;
    int target;
    if (entry != null) {
      consumed = entry.consumedMl;
      target = entry.targetMl;
    } else {
      consumed = 0;
      // 今天還沒存過紀錄：沿用上次存過的目標，完全沒有的話才用預設值
      target = await DBHelper.instance.getLatestWaterTarget() ?? _defaultTargetMl;
    }
    if (!mounted) return;
    setState(() {
      _consumedMl = consumed;
      _targetMl = target;
      _consumedCtrl.text = consumed.toString();
      _targetCtrl.text = target.toString();
      _loading = false;
    });
  }

  Future<void> _save() async {
    final consumed = int.tryParse(_consumedCtrl.text.trim());
    final target = int.tryParse(_targetCtrl.text.trim());
    if (consumed == null || consumed < 0 || target == null || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入正確的數字（攝取量 ≥ 0，目標 > 0）')),
      );
      return;
    }
    await DBHelper.instance.saveWaterLog(_todayStr, consumed, target);
    if (!mounted) return;
    setState(() {
      _consumedMl = consumed;
      _targetMl = target;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已更新喝水紀錄')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElementColors.background,
      appBar: AppBar(
        backgroundColor: ElementColors.background,
        foregroundColor: Colors.white,
        title: const Text('喝水'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                _waterIcon(),
                const SizedBox(height: 28),
                _numberField(
                  controller: _consumedCtrl,
                  label: '今日攝取量 (ml)',
                ),
                const SizedBox(height: 16),
                _numberField(
                  controller: _targetCtrl,
                  label: '每日目標 (ml)',
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ElementColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _save,
                    child: const Text('儲存'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _waterIcon() {
    return Column(
      children: [
        SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: CircularProgressIndicator(
                  value: _progress,
                  strokeWidth: 10,
                  backgroundColor: ElementColors.accentDim,
                  valueColor: const AlwaysStoppedAnimation(ElementColors.accent),
                ),
              ),
              const Icon(Icons.water_drop, size: 88, color: ElementColors.lightUi),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '$_consumedMl / $_targetMl ml',
          style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '${(_progress * 100).toStringAsFixed(0)}%',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ],
    );
  }

  Widget _numberField({required TextEditingController controller, required String label}) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: ElementColors.cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
