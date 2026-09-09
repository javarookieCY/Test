import 'package:flutter/material.dart';

import '../db_helper.dart';
import '../models/user_profile.dart';
import '../utils/constants.dart';
import '../utils/nutrition_math.dart';

/// 個人化資料設定頁。
/// 首次開 App（還沒有 profile）時會擋在最前面；之後也可從設定重新進來修改。
/// 送出後把資料存進 DB，並 pop 回傳新的 [UserProfile]。
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.initial});

  /// 有值代表「編輯」模式，欄位會預先填好。
  final UserProfile? initial;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _ageCtrl;

  Sex _sex = Sex.male;
  ActivityLevel _activity = ActivityLevel.light;
  Goal _goal = Goal.maintain;

  bool _saving = false;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _heightCtrl = TextEditingController(text: p?.heightCm.toStringAsFixed(0) ?? '');
    _weightCtrl = TextEditingController(text: p?.weightKg.toStringAsFixed(1) ?? '');
    _ageCtrl = TextEditingController(text: p?.age.toString() ?? '');
    if (p != null) {
      _sex = p.sex;
      _activity = p.activity;
      _goal = p.goal;
    }
    // 任一欄位改動就重算下方預覽
    for (final c in [_heightCtrl, _weightCtrl, _ageCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  /// 目前欄位若都有效，回傳試算目標；否則 null。
  NutritionTargets? get _previewTargets {
    final h = double.tryParse(_heightCtrl.text.trim());
    final w = double.tryParse(_weightCtrl.text.trim());
    final a = int.tryParse(_ageCtrl.text.trim());
    if (h == null || w == null || a == null) return null;
    if (h < 100 || h > 250 || w < 25 || w > 400 || a < 10 || a > 120) return null;
    return computeTargets(
      sex: _sex,
      weightKg: w,
      heightCm: h,
      age: a,
      activity: _activity,
      goal: _goal,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final profile = UserProfile(
      heightCm: double.parse(_heightCtrl.text.trim()),
      weightKg: double.parse(_weightCtrl.text.trim()),
      age: int.parse(_ageCtrl.text.trim()),
      sex: _sex,
      activity: _activity,
      goal: _goal,
    );

    try {
      await DBHelper.instance.saveUserProfile(profile);
      if (!mounted) return;
      Navigator.pop(context, profile);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('儲存失敗，請稍後再試')),
      );
    }
  }

  // 右上角 (i) 按鈕：解釋 BMR 與 TDEE 是什麼
  void _showFormulaInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ElementColors.cardBg,
        title: const Text('BMR 與 TDEE', style: TextStyle(color: Colors.white)),
        content: const SingleChildScrollView(
          child: DefaultTextStyle(
            style: TextStyle(color: Colors.white70, height: 1.6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('BMR（基礎代謝率）',
                    style: TextStyle(
                        color: ElementColors.lightUi, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('身體在完全靜止（躺著不動、不消化食物）一整天為了維持心跳、呼吸、'
                    '體溫等基本運作所消耗的最低熱量。\n\n'
                    '本 App 用 Mifflin-St Jeor 公式估算：\n'
                    '男：10×體重(kg) + 6.25×身高(cm) − 5×年齡 + 5\n'
                    '女：10×體重(kg) + 6.25×身高(cm) − 5×年齡 − 161'),
                SizedBox(height: 16),
                Text('TDEE（每日總消耗熱量）',
                    style: TextStyle(
                        color: ElementColors.lightUi, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('BMR 再加上你每天『日常非運動活動』（走路、工作、通勤）消耗的熱量。\n\n'
                    'TDEE = BMR × 活動係數（久坐 1.20 ～ 非常高 1.90）。\n\n'
                    '吃得比 TDEE 少會減重、多會增重。App 依你的目標把 TDEE '
                    '調整成每日熱量目標：減脂 −15%、維持 ±0、增肌 +10%。'),
                SizedBox(height: 16),
                Text('刻意運動呢？',
                    style: TextStyle(
                        color: ElementColors.lightUi, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('這裡的活動量『不包含』你去健身房、跑步等刻意運動——那些請在'
                    '「運動」頁單獨記錄，消耗的熱量會加回當天的剩餘熱量。\n\n'
                    '這樣運動只會被算一次，不會因為「活動量已含運動、又另外記錄」而重複計算。'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('了解'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElementColors.background,
      appBar: AppBar(
        backgroundColor: ElementColors.background,
        foregroundColor: Colors.white,
        title: Text(_isEdit ? '編輯個人資料' : '設定你的目標'),
        automaticallyImplyLeading: _isEdit, // 首次設定不給返回
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'BMR / TDEE 說明',
            onPressed: _showFormulaInfo,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!_isEdit)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  '填一次基本資料，App 會用 Mifflin-St Jeor 公式算出每天的熱量與三大營養素目標。',
                  style: TextStyle(color: Colors.white70, height: 1.5),
                ),
              ),
            _numberField(
              controller: _heightCtrl,
              label: '身高 (cm)',
              min: 100,
              max: 250,
            ),
            _numberField(
              controller: _weightCtrl,
              label: '體重 (kg)',
              min: 25,
              max: 400,
              decimal: true,
            ),
            _numberField(
              controller: _ageCtrl,
              label: '年齡',
              min: 10,
              max: 120,
            ),
            const SizedBox(height: 20),
            _label('性別'),
            SegmentedButton<Sex>(
              style: segmentedStyleOnDark(),
              segments: const [
                ButtonSegment(value: Sex.male, label: Text('男')),
                ButtonSegment(value: Sex.female, label: Text('女')),
              ],
              selected: {_sex},
              onSelectionChanged: (s) => setState(() => _sex = s.first),
            ),
            const SizedBox(height: 20),
            _label('活動量'),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '指日常生活與工作的活動程度，不含刻意運動（運動在「運動」頁另計）',
                style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
              ),
            ),
            ...ActivityLevel.values.map(
              (lvl) => _ChoiceTile(
                label: lvl.label,
                selected: _activity == lvl,
                onTap: () => setState(() => _activity = lvl),
              ),
            ),
            const SizedBox(height: 20),
            _label('目標'),
            SegmentedButton<Goal>(
              style: segmentedStyleOnDark(),
              segments: const [
                ButtonSegment(value: Goal.cut, label: Text('減脂')),
                ButtonSegment(value: Goal.maintain, label: Text('維持')),
                ButtonSegment(value: Goal.bulk, label: Text('增肌')),
              ],
              selected: {_goal},
              onSelectionChanged: (s) => setState(() => _goal = s.first),
            ),
            const SizedBox(height: 24),
            _preview(),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ElementColors.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: ElementColors.accentDim,
              ),
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? '儲存' : '開始使用'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: kGreyBoldText),
      );

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required double min,
    required double max,
    bool decimal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
        ),
        validator: (raw) {
          final v = double.tryParse((raw ?? '').trim());
          if (v == null) return '請輸入數字';
          if (v < min || v > max) return '請輸入 $min–$max 之間';
          return null;
        },
      ),
    );
  }

  Widget _preview() {
    final t = _previewTargets;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ElementColors.dayBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: t == null
          ? const Text(
              '填完上面欄位，這裡會即時試算你的每日目標',
              style: TextStyle(color: Colors.white54),
            )
          : DefaultTextStyle(
              style: const TextStyle(color: Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('每日目標（${_goal.label}）', style: kGreyBoldText),
                  const SizedBox(height: 8),
                  Text('熱量　${t.calories} kcal',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('蛋白質 ${t.proteinG} g　碳水 ${t.carbsG} g　脂肪 ${t.fatG} g'),
                  const SizedBox(height: 4),
                  Text(
                    'BMR ${t.bmr.round()} ・ TDEE ${t.tdee.round()} kcal',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
    );
  }
}

/// 單選清單的一列（取代已被 deprecate 的 RadioListTile group API）。
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? ElementColors.accent : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
