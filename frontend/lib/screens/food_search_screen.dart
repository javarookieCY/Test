import 'dart:async';

import 'package:flutter/material.dart';

import '../db_helper.dart';
import '../models/food_ref_item.dart';
import '../utils/constants.dart';

/// 「手動搜尋」：使用者打中文，像 Google 一樣打第一個字就即時跳出相關食品。
/// 點一筆就把它加進使用者的餐點庫（透過 [onPick] 回呼，回傳是否成功）。
/// 畫面不會馬上關閉，方便一次挑好幾樣，挑完按左上角返回。
class FoodSearchScreen extends StatefulWidget {
  const FoodSearchScreen({super.key, required this.onPick});

  /// 把選到的參考食品加進餐點庫；回傳 true 代表成功。
  final Future<bool> Function(FoodRefItem item) onPick;

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  String _query = '';
  List<FoodRefItem> _results = const [];
  bool _loading = false;
  int _reqId = 0; // 防止較舊的查詢覆蓋較新的結果

  // 這次畫面內已加入過的 ref_code，用來把該列標成「已加入」
  final Set<String> _added = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // 常見食材：空查詢時直接列在畫面上，點一下就帶入搜尋
  static const _commonFoods = [
    '白飯', '雞蛋', '雞胸', '地瓜', '豆漿',
    '牛奶', '香蕉', '蘋果', '花椰菜', '燕麥',
  ];

  void _setQuery(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
    _onChanged(value);
  }

  void _onChanged(String raw) {
    final q = raw.trim();
    setState(() => _query = q);

    _debounce?.cancel();
    if (q.isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }
    // 打第一個字就開始查，但用 180ms debounce 避免每個 keystroke 都打 DB
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 180), () => _run(q));
  }

  Future<void> _run(String q) async {
    final myReq = ++_reqId;
    final items = await DBHelper.instance.searchFoodRef(q);
    if (!mounted || myReq != _reqId) return; // 已有更新的查詢
    setState(() {
      _results = items;
      _loading = false;
    });
  }

  Future<void> _pick(FoodRefItem item) async {
    final ok = await widget.onPick(item);
    if (!mounted) return;
    if (ok) {
      setState(() => _added.add(item.refCode));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('已加入「${item.name}」到餐點庫')));
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('加入失敗，請稍後再試')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElementColors.background,
      appBar: AppBar(
        backgroundColor: ElementColors.background,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          cursorColor: Colors.white,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: '搜尋食品，例如：雞、地瓜、豆漿',
            hintStyle: const TextStyle(color: Colors.white54),
            border: InputBorder.none,
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white54),
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                    },
                  ),
          ),
          onChanged: _onChanged,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_query.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('常見食材', style: kGreyBoldText),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _commonFoods
                .map(
                  (name) => ActionChip(
                    label: Text(name),
                    labelStyle: const TextStyle(color: Colors.white),
                    backgroundColor: ElementColors.accentDim,
                    side: const BorderSide(color: ElementColors.accent),
                    onPressed: () => _setQuery(name),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            '或直接在上方輸入食品名稱\n資料來源：食品營養成分資料庫（每 100 克）',
            style: TextStyle(color: Colors.white38, height: 1.5),
          ),
        ],
      );
    }
    if (_loading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return _Hint(icon: Icons.sentiment_dissatisfied, text: '找不到「$_query」相關的食品');
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, color: Colors.white12),
      itemBuilder: (context, i) {
        final item = _results[i];
        final added = _added.contains(item.refCode);
        return ListTile(
          title: _HighlightText(text: item.name, query: _query),
          subtitle: Text(
            _subtitle(item),
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          trailing: added
              ? const Icon(Icons.check_circle, color: ElementColors.accent)
              : const Icon(Icons.add_circle_outline, color: Colors.white70),
          onTap: added ? null : () => _pick(item),
        );
      },
    );
  }

  String _subtitle(FoodRefItem it) {
    final macros = <String>[
      '${it.calories} kcal',
      if (it.protein != null) '蛋白 ${it.protein!.toStringAsFixed(1)}g',
      if (it.carbs != null) '碳水 ${it.carbs!.toStringAsFixed(1)}g',
      if (it.fat != null) '脂肪 ${it.fat!.toStringAsFixed(1)}g',
    ].join('  ');
    final alias = (it.alias == null || it.alias!.isEmpty) ? '' : '  ·  ${it.alias}';
    return '$macros$alias';
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// 把命中的關鍵字在食品名稱裡標成淺藍色，像搜尋引擎的做法。
class _HighlightText extends StatelessWidget {
  const _HighlightText({required this.text, required this.query});
  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(color: Colors.white, fontSize: 16);
    final idx = query.isEmpty ? -1 : text.indexOf(query);
    if (idx < 0) return Text(text, style: base);
    return RichText(
      text: TextSpan(
        style: base,
        children: [
          TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + query.length),
            style: const TextStyle(
              color: ElementColors.lightUi,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: text.substring(idx + query.length)),
        ],
      ),
    );
  }
}
