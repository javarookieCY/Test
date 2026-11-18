import 'dart:async';

import 'package:flutter/material.dart';

import '../../../database/database_service.dart';
import '../../../models/food_ref_item.dart';
import '../../../utils/constants.dart';

/// 「手動搜尋」：使用者打中文，像 Google 一樣打第一個字就即時跳出相關食品。
/// 點一筆就把它加進使用者的餐點庫（透過 onPick 回呼，回傳是否成功）。
/// 畫面不會馬上關閉，方便一次挑好幾樣，挑完按左上角返回。
class FoodSearchScreen extends StatefulWidget {
  const FoodSearchScreen({super.key, required this.onPick});

  /// 把選到的參考食品加進餐點庫；回傳 true 代表成功。
  /// 型別的意思：一個函式，收一個 FoodRefItem，回傳 `Future<bool>`
  final Future<bool> Function(FoodRefItem item) onPick;

  @override
  State<FoodSearchScreen> createState() {
    return _FoodSearchScreenState();
  }
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  // 搜尋框的控制器：可以讀取、設定搜尋框裡的文字
  final TextEditingController _controller = TextEditingController();

  // 延遲查詢用的計時器(debounce)：使用者停止打字 180 毫秒後才查
  Timer? _debounce;

  String _query = '';
  List<FoodRefItem> _results = <FoodRefItem>[];
  bool _loading = false;

  // 每次查詢的編號：防止「比較舊的查詢比較晚回來」把新的結果蓋掉
  int _requestId = 0;

  // 這次畫面內已加入過的 ref_code，用來把該列標成「已加入」
  final Set<String> _added = <String>{};

  // 常見食材：空查詢時直接列在畫面上，點一下就帶入搜尋
  static const List<String> _commonFoods = <String>[
    '白飯', '雞蛋', '雞胸', '地瓜', '豆漿',
    '牛奶', '香蕉', '蘋果', '花椰菜', '燕麥',
  ];

  @override
  void dispose() {
    final Timer? debounce = _debounce;
    if (debounce != null) {
      debounce.cancel();
    }
    _controller.dispose();
    super.dispose();
  }

  /// 點了常見食材：把它填進搜尋框並開始搜尋
  void _setQuery(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length); // 游標移到最後面
    _onChanged(value);
  }

  /// 搜尋框文字改變時呼叫
  void _onChanged(String raw) {
    final String trimmed = raw.trim();
    setState(() {
      _query = trimmed;
    });

    // 取消上一次還沒執行的查詢
    final Timer? oldDebounce = _debounce;
    if (oldDebounce != null) {
      oldDebounce.cancel();
    }

    if (trimmed.isEmpty) {
      setState(() {
        _results = <FoodRefItem>[];
        _loading = false;
      });
      return;
    }

    // 打第一個字就開始查，但用 180ms debounce 避免每打一個字都查一次資料庫
    setState(() {
      _loading = true;
    });
    _debounce = Timer(const Duration(milliseconds: 180), () {
      _run(trimmed);
    });
  }

  /// 真的去資料庫查詢
  Future<void> _run(String keyword) async {
    _requestId = _requestId + 1;
    final int myRequestId = _requestId;

    final List<FoodRefItem> items = await DatabaseService.instance.searchFoodRef(keyword);

    // 頁面已經關了，或已經有更新的查詢：這次的結果不要了
    if (!mounted) {
      return;
    }
    if (myRequestId != _requestId) {
      return;
    }

    setState(() {
      _results = items;
      _loading = false;
    });
  }

  /// 點了一筆搜尋結果：加進餐點庫
  Future<void> _pick(FoodRefItem item) async {
    final bool ok = await widget.onPick(item);
    if (!mounted) {
      return;
    }

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    if (ok) {
      setState(() {
        _added.add(item.refCode);
      });
      final String name = item.name;
      messenger.showSnackBar(SnackBar(content: Text('已加入「$name」到餐點庫')));
    } else {
      messenger.showSnackBar(const SnackBar(content: Text('加入失敗，請稍後再試')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 搜尋框有字時，右邊才顯示「清除」按鈕
    Widget? clearButton;
    if (_query.isNotEmpty) {
      clearButton = IconButton(
        icon: const Icon(Icons.clear, color: Colors.white54),
        onPressed: () {
          _controller.clear();
          _onChanged('');
        },
      );
    }

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
            suffixIcon: clearButton,
          ),
          onChanged: (String value) {
            _onChanged(value);
          },
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 1. 還沒輸入：顯示常見食材
    if (_query.isEmpty) {
      final List<Widget> chips = <Widget>[];
      for (final String name in _commonFoods) {
        final Widget chip = ActionChip(
          label: Text(name),
          labelStyle: const TextStyle(color: Colors.white),
          backgroundColor: ElementColors.accentDim,
          side: const BorderSide(color: ElementColors.accent),
          onPressed: () {
            _setQuery(name);
          },
        );
        chips.add(chip);
      }

      return ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          const Text('常見食材', style: kGreyBoldText),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips,
          ),
          const SizedBox(height: 24),
          const Text(
            '或直接在上方輸入食品名稱\n資料來源：食品營養成分資料庫（每 100 克）',
            style: TextStyle(color: Colors.white38, height: 1.5),
          ),
        ],
      );
    }

    // 2. 查詢中，而且還沒有任何結果：轉圈圈
    if (_loading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 3. 查完了但找不到
    if (_results.isEmpty) {
      return _Hint(icon: Icons.sentiment_dissatisfied, text: '找不到「$_query」相關的食品');
    }

    // 4. 有結果：列出來，每一列中間用細線隔開
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (BuildContext context, int index) {
        return const Divider(height: 1, color: Colors.white12);
      },
      itemBuilder: (BuildContext context, int index) {
        final FoodRefItem item = _results[index];
        final bool added = _added.contains(item.refCode);

        // 已加入：打勾圖示、不能再點；還沒加入：加號圖示、點了就加入
        Widget trailingIcon;
        VoidCallback? onTap;
        if (added) {
          trailingIcon = const Icon(Icons.check_circle, color: ElementColors.accent);
          onTap = null;
        } else {
          trailingIcon = const Icon(Icons.add_circle_outline, color: Colors.white70);
          onTap = () {
            _pick(item);
          };
        }

        return ListTile(
          title: _HighlightText(text: item.name, query: _query),
          subtitle: Text(
            _subtitle(item),
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          trailing: trailingIcon,
          onTap: onTap,
        );
      },
    );
  }

  /// 搜尋結果的副標題，例如「140 kcal  蛋白 12.6g  碳水 1.1g  脂肪 9.5g  ·  雞蛋,蛋」
  String _subtitle(FoodRefItem item) {
    final List<String> parts = <String>[];

    final int calories = item.calories;
    parts.add('$calories kcal');

    // 營養素可能是 null(資料缺值)，有值才顯示；toStringAsFixed(1) = 取到小數點後 1 位
    final double? protein = item.protein;
    if (protein != null) {
      final String text = protein.toStringAsFixed(1);
      parts.add('蛋白 ${text}g');
    }
    final double? carbs = item.carbs;
    if (carbs != null) {
      final String text = carbs.toStringAsFixed(1);
      parts.add('碳水 ${text}g');
    }
    final double? fat = item.fat;
    if (fat != null) {
      final String text = fat.toStringAsFixed(1);
      parts.add('脂肪 ${text}g');
    }

    final String macros = parts.join('  ');

    // 有俗名才在後面加上「 · 俗名」
    String aliasText = '';
    final String? alias = item.alias;
    if (alias != null && alias.isNotEmpty) {
      aliasText = '  ·  $alias';
    }

    return '$macros$aliasText';
  }
}

/// 提示訊息：一個大圖示加一行灰色文字
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
          children: <Widget>[
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
    const TextStyle baseStyle = TextStyle(color: Colors.white, fontSize: 16);

    // 關鍵字在名稱裡的位置；找不到是 -1
    int matchIndex = -1;
    if (query.isNotEmpty) {
      matchIndex = text.indexOf(query);
    }

    if (matchIndex < 0) {
      return Text(text, style: baseStyle);
    }

    // 名稱切成三段：關鍵字前面、關鍵字本身(標色)、關鍵字後面
    final int matchEnd = matchIndex + query.length;
    final String before = text.substring(0, matchIndex);
    final String matched = text.substring(matchIndex, matchEnd);
    final String after = text.substring(matchEnd);

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: <TextSpan>[
          TextSpan(text: before),
          TextSpan(
            text: matched,
            style: const TextStyle(
              color: ElementColors.lightUi,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }
}
