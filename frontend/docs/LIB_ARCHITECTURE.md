# `lib/` 架構與變數 / 方法說明

> 本文件掃描 `frontend/lib/` 底下全部 26 支 Dart 檔案，逐檔說明每個類別、欄位（變數）與方法的用途，
> 並整理檔案之間的相依關係與實際資料流程，方便日後維護或加新功能時快速定位。
>
> App 定位：一款**熱量記錄 + 運動紀錄**的 Flutter App（深色主題），核心功能：
> 1. 依身高/體重/年齡/性別/活動量/目標，用 Mifflin-St Jeor 公式算出每日熱量與三大營養素目標
> 2. 記錄三餐食物攝取（可從「餐點庫」挑選、從 TFDA 營養資料庫搜尋、或手動輸入）
> 3. 記錄運動消耗，並把消耗的熱量加回當天「剩餘熱量」
> 4. 本機 SQLite（`sqflite` / `sqflite_common_ffi`）持久化所有資料，無後端伺服器、無狀態管理套件（不用 Provider / Riverpod / Bloc），純粹用 `StatefulWidget` + `setState` + callback + `DBHelper` 單例。

---

## 1. 目錄結構

```
lib/
├── main.dart                       # App 進入點
├── db_helper.dart                  # SQLite 存取層（唯一資料庫入口，單例）
├── models/                         # 純資料結構（DTO）
│   ├── exercise_entry.dart
│   ├── food_item.dart
│   ├── food_ref_item.dart
│   ├── meal_item.dart
│   └── user_profile.dart
├── screens/                        # 各頁面（Route 層級）
│   ├── root_shell.dart             # App 外殼：底部導覽 + 三頁 PageView
│   ├── home_screen.dart            # 「日記」主頁（最複雜）
│   ├── onboarding_screen.dart      # 個人資料設定 / 編輯
│   ├── exercise_screen.dart        # 「運動」頁
│   ├── food_search_screen.dart     # 食品營養資料庫搜尋
│   └── coming_soon_screen.dart     # 「健身」頁（尚未實作的佔位頁）
├── utils/                          # 無 UI 邏輯 / 共用資源
│   ├── constants.dart              # 色票、共用 TextStyle / ButtonStyle
│   ├── exercise_data.dart          # 運動預設資料 + 熱量估算公式
│   ├── nutrition_math.dart         # BMR/TDEE/三大營養素試算（純 Dart，無 Flutter 依賴）
│   └── scroll_behavior.dart        # 自訂捲動行為（讓滑鼠也能拖曳捲動）
└── widgets/                        # 可重用 UI 元件，依畫面分資料夾
    ├── home/
    │   ├── calories_info.dart      # 尚未設定個人資料時的簡易熱量卡
    │   ├── daily_target_card.dart  # 已設定個人資料後的「每日目標」卡
    │   ├── home_header.dart        # 頁首（日期 + 通知鈴鐺）
    │   ├── streak_section.dart     # 連續記錄列 + 可展開的飲食方案區
    │   └── week_row.dart           # 一週日期選擇列
    ├── meals/
    │   ├── meal_card.dart          # 單一餐別（早餐/午餐…）卡片
    │   └── meal_entry.dart         # 把 5 個 MealCard 組起來的容器
    └── plans/
        ├── plan_carousel.dart      # 飲食方案的無限輪播卡片
        └── plan_detail_sheet.dart  # 點卡片後彈出的方案詳情
```

### 分層關係（由上到下）

```
main.dart
  └─ RootShell (screens)
       ├─ ExerciseScreen ───────┐
       ├─ MyHomePage (home) ────┼──▶ DBHelper（單例，唯一資料庫窗口）
       └─ ComingSoonScreen      │        │
                                │        ▼
       screens/* ── widgets/* ─┘   SQLite (meals.db)
            │
            ▼
       models/*  (在 DB ↔ UI 之間搬資料的純物件)
            │
            ▼
       utils/*   (無狀態的純函式 / 常數，被 screens、widgets、models 共同引用)
```

---

## 2. 逐檔說明

### 2.1 `lib/main.dart`

App 的進入點。

| 名稱 | 類型 | 說明 |
|---|---|---|
| `main()` | 函式 | Dart/Flutter 進入點。用 `DevicePreview`（`enabled: true`）包住 `MyApp`，讓開發時可以在單一視窗內預覽不同裝置尺寸與語系（正式上架前應把 `enabled` 改為看環境變數或直接拿掉）。 |
| `MyApp` | `StatelessWidget` | App 根 widget。 |
| `MyApp.build()` | 方法 | 建立 `MaterialApp`：<br>• `locale: DevicePreview.locale(context)`、`builder: DevicePreview.appBuilder` — 讓 DevicePreview 生效<br>• `scrollBehavior: MyScrollBehavior()` — 見 `utils/scroll_behavior.dart`<br>• `theme`：深色 `ColorScheme.fromSeed(seedColor: ElementColors.accent, brightness: Brightness.dark)`，即全 App 配色都是從 `constants.dart` 的 `accent` 色推導<br>• `home: const RootShell()` — 實際畫面入口 |

---

### 2.2 `lib/db_helper.dart`

**全 App 唯一的 SQLite 存取層**，用單例模式（`DBHelper.instance`）讓所有 screen 都能直接呼叫，不需要注入。

#### 欄位

| 名稱 | 類型 | 說明 |
|---|---|---|
| `DBHelper._()` | 私有建構子 | 禁止外部 `new`，強制走單例 |
| `instance` | `static final DBHelper` | 全域唯一實例 |
| `_db` | `Database?` | 快取住的資料庫連線，第一次用到才會開 |
| `_factoryInitialized` | `static bool` | 避免重複初始化 sqflite ffi 工廠 |
| `database` | `Future<Database>` getter | 對外唯一取得 DB 連線的入口：有快取就回傳，沒有就呼叫 `_initDB()` |

#### 初始化

| 方法 | 說明 |
|---|---|
| `_ensureFactoryInitialized()` | 判斷是否為桌面平台（Windows/Linux/macOS，且非 Web）。桌面平台預設的 `sqflite` 外掛不支援，必須改用 `sqflite_common_ffi` 的 `databaseFactoryFfi`，此方法就是做這個切換，且只做一次。 |
| `_initDB()` | 用 `openDatabase` 開啟（或建立）`meals.db`，目前 `version: 7`。`onCreate` 建立全部 7 張表；`onUpgrade` 依 `oldVersion` 做**逐步遞增式**的 schema migration（`< 2` 建 foods、`< 3` 建 meal_foods、`< 4` 幫 foods 加欄位、`< 5` 建 food_ref、`< 6` 建 user_profile/weight_log、`< 7` 建 exercises）。開完 DB 後呼叫 `_seedFoodRefIfEmpty` 灌入內建營養資料。 |
| `_createFoodRefSql` / `_createUserProfileSql` / `_createWeightLogSql` / `_createExercisesSql` | `static const` SQL 建表字串，`onCreate` 與 `onUpgrade` 共用，避免兩處 SQL 語法不同步。 |
| `_foodRefAsset` | `'assets/data/food_ref.json'`，內建營養參考資料的 asset 路徑（來源：`tools/import_nutrition/build_food_ref.py` 由 TFDA CSV 轉出）。 |
| `_seedFoodRefIfEmpty(db)` | 檢查 `food_ref` 表是否為空；空的話才從 asset 讀 JSON、用 `db.transaction` + `batch()` 一次性大量插入（效能考量），失敗只印 log 不丟例外，避免影響 App 啟動。 |

#### 資料表對應的 CRUD 方法

| 資料表 | 方法 | 說明 |
|---|---|---|
| `meals`（每日「異動」歷史紀錄，可想成流水帳） | `insertMeal(title, calories, date)` | 新增一筆熱量異動（`home_screen` 在使用者調整某餐熱量時，把**差值**寫進來，非目前總量） |
| | `getMealsByDate(date)` | 目前程式碼中沒有被其他檔案呼叫（保留的查詢介面） |
| `foods`（使用者自訂餐點庫模板） | `insertFood(FoodItem)` / `getAllFoods()` / `deleteFood(id)` / `updateFood(FoodItem)` | 標準 CRUD，供「管理餐點庫」對話框使用 |
| `meal_foods`（**目前**每天每餐每項食物的即時狀態，`UNIQUE(date, meal_title, food_name)`） | `upsertMealFood(date, mealTitle, foodName, calories, portion)` | 用 `ConflictAlgorithm.replace`，同一天同一餐同一食物再存一次會直接覆蓋（改份量） |
| | `deleteMealFood(date, mealTitle, foodName)` | 份量歸零時刪除該列 |
| | `getMealFoodsByDate(date)` | 載入某天所有餐點明細，用來還原 UI 上的 `MealItem.items` |
| `food_ref`（TFDA 食品營養參考庫，唯讀） | `getFoodRefCount()` | 未被其他檔案呼叫，保留介面 |
| | `searchFoodRef(keyword, {limit = 30})` | `LIKE` 查 `name`/`alias`，用 `CASE WHEN` 把「完全前綴命中」排最前、其次「包含命中」，再依名稱長度、字母排序——模擬「越像的排越前面」的搜尋體驗 |
| | `getFoodRefByCode(refCode)` | 未被其他檔案呼叫，保留介面 |
| `user_profile`（只會有 1 列，`id` 固定為 1） | `getUserProfile()` | 讀 `id=1` 那列，沒有回傳 `null`（代表使用者還沒做過 Onboarding） |
| | `saveUserProfile(profile)` | `ConflictAlgorithm.replace` upsert，並同時呼叫 `logWeight(today, profile.weightKg)` 讓體重紀錄同步 |
| `weight_log`（每天一筆體重，`date` 為主鍵） | `logWeight(date, weightKg)` | upsert；若寫入的日期正好是今天，**額外**把 `user_profile.weight_kg` 也同步更新（因為目標試算要用「最新體重」） |
| | `getWeightLog({limit = 90})` | 依日期新到舊排序，未被其他檔案呼叫（保留的查詢介面，可能是給尚未實作的體重趨勢圖用） |
| | `_todayStr()` | `static` helper，把 `DateTime.now()` 轉成 `'yyyy-M-d'`（注意**月、日沒有補零**，這個格式與 `home_screen.dart`、`exercise_screen.dart` 裡各自手刻的日期字串格式必須保持一致，否則會查不到資料） |
| `exercises`（每日運動紀錄） | `insertExercise(ExerciseEntry)` / `getExercisesByDate(date)`（依 `id DESC`，新的在前）/ `deleteExercise(id)` | 標準 CRUD |
| | `getBurnedCaloriesByDate(date)` | `SUM(calories)`（用 `COALESCE` 防止沒紀錄時回傳 `null`），供首頁「剩餘熱量」把運動消耗加回去 |

---

### 2.3 `lib/models/` — 純資料結構

#### `exercise_entry.dart` — `ExerciseEntry`
對應 `exercises` 表的一列。

| 欄位 | 型別 | 說明 |
|---|---|---|
| `id` | `int?` | DB 主鍵，新建時為 `null` |
| `date` | `String` | `yyyy-M-d` |
| `name` | `String` | 運動名稱，**已把強度也拼進字串**（如「跑步（中等 6:00/km）」），因為表沒有獨立的強度欄位 |
| `minutes` | `int` | 時長 |
| `calories` | `int` | 消耗熱量 |

`toMap()` / `fromMap()`：與 DB Map 互轉（`fromMap` 對數字型別用 `(x as num).toInt()`，容忍 DB 回傳 `int`/`double`/`num` 的差異）。

#### `food_item.dart` — `FoodItem`
使用者「餐點庫」裡的一個食物模板。

| 欄位 | 型別 | 說明 |
|---|---|---|
| `id` | `int?` | 主鍵，未存入 DB 前為 `null` |
| `name` | `String` | 食物名稱 |
| `calories` | `int` | 熱量（這個模板一份的熱量，非每 100g） |
| `protein` / `carbs` / `fat` | `double`（預設 0） | 三大營養素 |
| `imagePath` | `String?` | 圖片 asset 路徑，有值才會出現在「預設餐點」卡片牆（目前實際程式沒有地方在讀這個欄位畫圖，是保留欄位） |
| `description` | `String?` | 內容物說明，例如從食品搜尋頁加入時會自動填「每 100 克｜來源：食品營養成分資料庫」 |

`toMap()` / `fromMap()`：DB 互轉。

#### `food_ref_item.dart` — `FoodRefItem`
對應 `food_ref` 表，**唯讀**的 TFDA 營養成分參考資料，所有數值都是「每 100 克」。

| 欄位 | 型別 | 說明 |
|---|---|---|
| `id` | `int?` | DB 主鍵 |
| `refCode` | `String` | 整合編號（如 `B0700201`），DB 內 `UNIQUE` |
| `name` | `String` | 樣品名稱 |
| `alias` | `String?` | 俗名，逗號分隔 |
| `category` | `String?` | 食品分類 |
| `calories` | `int` | 熱量（來源為浮點數，匯入/讀取時四捨五入成整數） |
| `protein` / `carbs` / `fat` / `fiber` / `sodium` / `water` | `double?` | 少數樣品缺值會是 `null` |

`fromMap()`：從 SQLite 查詢結果建立（含 `id`）。
`fromJson()`：從 `assets/data/food_ref.json` 建立（**不含** `id`，因為還沒 insert），供 `DBHelper._seedFoodRefIfEmpty` 首次灌資料用。
`toMap()`：轉回 DB Map（給 `batch.insert` 用）。

#### `meal_item.dart`

| 名稱 | 說明 |
|---|---|
| `MealFoodRecord` | 一餐裡的一個品項：`name`（String）、`calories`（int，該品項在此份量下的總熱量）、`portion`（double，份量倍數，如 1.5 份） |
| `MealItem` | 一個「餐別」（早餐/午餐/…）：`title`（`final String`，識別用不可變）、`calories`（`int`，該餐總熱量，**可變**、由外部累加/歸零）、`items`（`List<MealFoodRecord>`，若建構時傳 `null` 會自動變空陣列）。整個 App 只在 `home_screen.dart` 建立 5 個固定的 `MealItem` 實例，之後全程用**原地修改**（mutate in place）而不是重新 new，因此它們的欄位刻意設計成非 `final` |
| `MealFoodAdded` | `typedef`：`void Function(String mealTitle, String foodName, int calories, double portion)`，是 `MealEntry → home_screen` 之間回呼事件的簽名，統一了「新增/修改/移除（portion≤0）一個品項」這件事 |

#### `plan_item.dart` — `PlanItem`
不可變（全部 `final`）的飲食方案資料：`title`、`imagePath`、`description`、`dietRules`（`List<String>`）。目前資料來源是 `home_screen.dart` 裡手刻的 3 筆 `const` 範例（低碳/地中海/高蛋白），非資料庫。

#### `user_profile.dart`

| 名稱 | 說明 |
|---|---|
| `UserProfile` | 使用者個人資料（DB 只存 1 列，`id` 固定為 1）：`heightCm`、`weightKg`（**最近一次**體重，也會同步寫進 `weight_log`）、`age`、`sex`（`Sex` enum）、`activity`（`ActivityLevel` enum）、`goal`（`Goal` enum） |
| `UserProfile.targets` | **getter，不是欄位**——每次存取都即時呼叫 `nutrition_math.computeTargets(...)` 重新計算，不做快取。代表任何一頁只要拿到 `_profile`，永遠能拿到跟目前欄位一致的最新目標，不用擔心快取沒更新 |
| `copyWith(...)` | 標準 immutable-update pattern，目前沒有任何地方呼叫（保留 API） |
| `toMap()` | 轉 DB Map；`id` 固定寫 `1`；enum 用 `.name` 存成字串 |
| `fromMap()` | 從 DB Map 建立；enum 用 `Enum.values.byName(...)` 還原 |
| `WeightEntry` | 一筆體重紀錄：`date`、`weightKg`。只有 `fromMap()`，因為寫入時 `DBHelper.logWeight` 是直接組 Map insert，不經過這個 model 的 `toMap` |

---

### 2.4 `lib/screens/`

#### `root_shell.dart` — `RootShell`
App 的外層骨架：三頁橫向滑動（運動 / 日記 / 健身）+ 底部導覽列。**是唯一負責串接「運動頁」與「日記頁」的地方**。

| 名稱 | 說明 |
|---|---|
| `_initialPage` | `static const 1`，App 一打開預設停在中間的「日記」頁 |
| `_controller` | `PageController`，驅動 `PageView` |
| `_index` | 目前顯示中的分頁索引，用來高亮底部導覽列 |
| `_exerciseTick` | **跨頁通訊用的計數器**：每當 `ExerciseScreen` 新增/刪除一筆運動紀錄，就會透過 `onChanged` callback 通知 `RootShell` 把這個數字 `+1`，再當作 prop 傳給 `MyHomePage(exerciseTick: _exerciseTick)`。`MyHomePage` 沒有直接的方法可以「被外部呼叫」，所以借用 Flutter 的 `didUpdateWidget` 生命週期：只要傳入的 prop 變了，`State` 就會收到通知，藉此讓日記頁知道「運動資料變了，該重抓消耗熱量」 |
| `initState()` / `dispose()` | 建立/釋放 `_controller` |
| `_goTo(i)` | 底部導覽列被點擊時，用動畫捲到第 `i` 頁 |
| `build()` | `Scaffold` 包 `PageView`（子項：`ExerciseScreen`、`MyHomePage`、`ComingSoonScreen`）+ `BottomNavigationBar` |

#### `home_screen.dart` — `MyHomePage`（**全 App 最核心、最複雜的畫面**，即「日記」頁）

**Widget 傳入參數**

| 名稱 | 說明 |
|---|---|
| `title` | 目前僅作為建構參數保留，畫面上沒有直接顯示 |
| `exerciseTick` | 來自 `RootShell`，見上方說明，預設 `0` |

**State 欄位**

| 名稱 | 型別 | 說明 |
|---|---|---|
| `_today` | `DateTime` | `initState` 時算一次、去掉時分秒的「今天」 |
| `_weekDates` | `List<DateTime>` | 本週（週一～週日）7 天日期，依 `_today` 推算 |
| `_selectedIndex` | `int` | 目前檢視中的星期幾（0=週一…6=週日） |
| `_streakCount` | `int` | 連續記錄天數。**只存在記憶體，不寫入 DB**，App 重啟就歸零 |
| `_lastLoggedDate` | `DateTime?` | 上次新增食物的日期，用來判斷連續天數是否該 +1、重置或不變 |
| `_foodLibrary` | `List<FoodItem>` | 使用者自訂餐點庫，從 `foods` 表讀出 |
| `_profile` | `UserProfile?` | `null` 代表還沒做過 Onboarding |
| `_mealItems` | `final List<MealItem>` | **固定 5 筆**（早餐/午餐/晚餐/宵夜/其他餐點），整個生命週期只建立一次，之後都是原地修改內容，不會被替換 |
| `_burnedCalories` | `int` | 目前檢視日期的運動消耗熱量 |
| `_samplePlans` | `const List<PlanItem>` | 硬編碼的 3 個飲食方案範例（低碳/地中海/高蛋白），非資料庫資料 |

**Getter（衍生狀態）**

| 名稱 | 公式 | 說明 |
|---|---|---|
| `_dailyCalorieBudget` | `_profile?.targets.calories ?? 2000` | 有個人資料就用試算值，沒有就用保守預設值 2000 |
| `_consumedCalories` | `_mealItems` 的 `calories` 加總 | 已攝取熱量 |
| `_remainingCalories` | `budget − consumed + burned` | 只有在**沒有** `_profile`（顯示 `CaloriesFetch`）時會用到；有 `_profile` 時改由 `DailyTargetCard` 自己算 |
| `_selectedDateLabel` | 依 `_selectedIndex` 對應日期與 `_today` 的差 | `'今天'` / `'昨天'` / `'明天'` / `'M/D'` |

**方法**

| 方法 | 說明 |
|---|---|
| `_isSameDay(a,b)` / `_isYesterday(a,b)` | 純日期比較 helper，服務連續記錄邏輯 |
| `_onFoodAddedToMeal(mealTitle, foodName, calories, portion)` | **全 App 最關鍵的寫入邏輯**。找到對應 `MealItem`，算出跟舊值的熱量差 `calorieDiff`；若有差就往 `meals` 表寫一筆異動紀錄；依 `portion` 是否 `<=0` 決定刪除或 upsert `meal_foods`；接著 `setState` 同步更新記憶體中的 `MealFoodRecord` 列表與 `meal.calories`，並在有新增熱量時（`calorieDiff > 0`）用 `_lastLoggedDate` 判斷今天是否要讓 `_streakCount` +1／重置／不變 |
| `_loadFoodLibrary()` | 讀 `foods` 表 → `_foodLibrary` |
| `_loadProfileThenGate()` | 讀 `user_profile`；沒有的話，等第一幀畫完（`addPostFrameCallback`，避免在 `build` 期間動 `Navigator`）才 push `OnboardingScreen`（`fullscreenDialog: true`，強制填寫、無法手動關閉） |
| `_editProfile()` | push `OnboardingScreen(initial: _profile)` 進入編輯模式，存檔後更新 `_profile` |
| `_showLogWeightDialog()` | 彈出對話框讓使用者輸入今天體重（驗證 25–400），存檔後呼叫 `DBHelper.logWeight` 並重新讀取 `_profile`（因為體重會影響 BMR/蛋白質目標） |
| `_loadBurnedForDate(date)` | 讀該日期的 `exercises` 消耗總和 → `_burnedCalories` |
| `_loadMealsForDate(date)` | 讀該日期的 `meal_foods`，**先清空**全部 `_mealItems` 的 `calories`/`items` 再依 `meal_title` 逐筆重建；同時呼叫 `_loadBurnedForDate` |
| `_addFoodToLibrary(food)` / `_updateFoodInLibrary(food)` | 包 `try/catch` 呼叫 `DBHelper.insertFood`/`updateFood` + 重新載入餐點庫，回傳 `bool` 讓呼叫端（對話框）知道是否該關閉 |
| `_deleteFoodFromLibrary(id)` | 刪除 + 重新載入 |
| `_openFoodSearch()` | push `FoodSearchScreen`，其 `onPick` 回呼把挑到的 `FoodRefItem`（每 100g 參考值）**直接**轉成一個新的 `FoodItem`（描述欄位自動加上來源說明），呼叫 `_addFoodToLibrary` 存入餐點庫 |
| `_showAddFoodDialog({foodToEdit})` | 新增/修改餐點共用的表單對話框（`foodToEdit` 是否為 `null` 決定是新增還是編輯模式）；內部驗證名稱非空、熱量為數字，儲存中用 `isSaving` 鎖住按鈕避免重複送出 |
| `_showManageFoodLibraryDialog()` | 列出 `_foodLibrary`，每列可編輯（關閉本對話框、開編輯表單）或刪除（呼叫刪除 + 用 `StatefulBuilder` 的 `setDialogState` 局部刷新列表，不驚動整個 `_MyHomePageState`） |
| `initState()` | 算好 `_today`/`_weekDates`/`_selectedIndex`，同時發起三個非同步載入：`_loadFoodLibrary()`、`_loadMealsForDate(今天)`、`_loadProfileThenGate()` |
| `didUpdateWidget(oldWidget)` | 偵測 `exerciseTick` 是否改變（來自 `RootShell`），有變就重抓目前選取日期的運動消耗 |
| `_selectDay(index)` | 切換週選單的選取日 + 重新載入該日資料 |
| `build()` | 由上到下組出：`HomeHeader` → `WeekRow` → `StreakInfoRow` → `FoodStreakSection`（飲食方案輪播）→ 依 `_profile` 是否存在切換 `DailyTargetCard` 或 `CaloriesFetch` → 三個功能按鈕（記錄體重/搜尋食品/管理餐點庫）→ `MealEntry`（5 張餐卡） |

#### `onboarding_screen.dart` — `OnboardingScreen`
個人化資料設定頁，**同時身兼兩種角色**：首次使用時的強制設定頁（`initial == null`）、之後的編輯頁（`initial != null`）。

| 名稱 | 說明 |
|---|---|
| `widget.initial` | 有值代表編輯模式，欄位會預先帶入 |
| `_formKey` | `GlobalKey<FormState>`，送出前呼叫 `.validate()` |
| `_heightCtrl` / `_weightCtrl` / `_ageCtrl` | 三個數字輸入框的 controller；`initState` 幫每個都加 `addListener(() => setState(() {}))`，讓**任何一個字**改動都觸發 rebuild，藉此讓下方「即時預覽」跟著更新 |
| `_sex` / `_activity` / `_goal` | 目前選擇的 enum 值，預設 `男/輕度活動/維持`，有 `initial` 就沿用舊值 |
| `_saving` | 送出中的 loading 旗標，避免重複送出、並切換按鈕為轉圈圈 |
| `_isEdit` | getter：`widget.initial != null` |
| `_previewTargets` | getter：解析目前三個欄位文字，範圍檢查（身高100–250、體重25–400、年齡10–120），全部合法才呼叫 `computeTargets(...)`，否則回傳 `null`（畫面顯示提示文字而非試算結果） |
| `_submit()` | 驗證表單 → 組出 `UserProfile` → `DBHelper.saveUserProfile` → `Navigator.pop(context, profile)` 把結果帶回上一頁；失敗則顯示 SnackBar 並解除 `_saving` |
| `_showFormulaInfo()` | 右上角 `(i)` 按鈕觸發，純文字說明 BMR/TDEE 公式，以及**為什麼「活動量」不含刻意運動**（避免跟運動頁的消耗熱量重複計算） |
| `_label()` / `_numberField()` / `_preview()` | 私有 UI 建構 helper，非邏輯 |
| `_ChoiceTile` | 私有 `StatelessWidget`：自製的單選列（取代已被 deprecate 的 `RadioListTile` group API），用於「活動量」清單 |

#### `exercise_screen.dart` — `ExerciseScreen`（「運動」頁）

| 名稱 | 說明 |
|---|---|
| `widget.onChanged` | `VoidCallback?`，新增/刪除紀錄後呼叫，通知 `RootShell` 把 `_exerciseTick` +1（見 `root_shell.dart`） |
| `_todayStr` | `initState` 時算一次的今天日期字串 |
| `_entries` | 今日的 `List<ExerciseEntry>` |
| `_profile` | 只用來取得 `weightKg` 給熱量估算公式使用 |
| `_totalMinutes` / `_totalCalories` | getter，`_entries` 的加總，顯示在上方統計卡 |
| `_load()` | 平行讀取今日 `exercises` 與 `user_profile` |
| `_addEntry(entry)` | insert → `_load()` → `widget.onChanged?.call()` |
| `_deleteEntry(id)` | delete → `_load()` → `widget.onChanged?.call()` |
| `_summaryCard()` / `_stat()` / `_entryTile()` / `_planCard()` | 純顯示 helper；`_planCard` 渲染 `exercise_data.dart` 的 `kWorkoutPlans`（靜態文字課表） |
| `_showRecordDialog()` | 「記錄運動」對話框，內部區域變數：<br>• `selected`：目前選的 `ExercisePreset`（預設第一筆「跑步」）<br>• `intensity`：目前選的 `ExerciseIntensity`<br>• `minutesCtrl` / `kcalCtrl`：輸入框<br>• `kcalEditedManually`：**一旦使用者手動改過熱量欄位，就停止自動估算**，尊重手動覆寫<br>• `recalc(setDialogState)`：呼叫 `estimateExerciseKcal(met, minutes, weightKg)` 重算預估熱量（除非已手動編輯）<br>存檔時把強度標籤一起拼進 `name`（因為 `exercises` 表沒有獨立強度欄位），並驗證分鐘數 > 0、熱量 ≥ 0 |

#### `food_search_screen.dart` — `FoodSearchScreen`
即時（像搜尋引擎）查詢 TFDA 食品營養庫的畫面。

| 名稱 | 說明 |
|---|---|
| `widget.onPick` | `Future<bool> Function(FoodRefItem)`，把選到的參考食品交回呼叫端（`home_screen._openFoodSearch`）處理「加進餐點庫」的實際邏輯，回傳是否成功 |
| `_controller` | 搜尋框（放在 `AppBar.title`）的 `TextEditingController` |
| `_debounce` | `Timer?`，**180ms** 防抖，避免每敲一個字就查一次 DB |
| `_query` | 目前 trim 過的查詢字串 |
| `_results` | 查詢結果 |
| `_loading` | 查詢中旗標 |
| `_reqId` | **競態條件保護**：每次查詢自增，`_run()` 回來時比對自己的編號是否仍是最新，避免「較舊的查詢比較新的查詢晚回來，結果覆蓋掉新結果」 |
| `_added` | `Set<String>`，記錄本次畫面內已加入過的 `refCode`，把該列標成「已加入」（打勾）避免重複加 |
| `_commonFoods` | `static const` 常見食材清單，查詢字串為空時顯示成可點的 chips |
| `_setQuery(value)` | 點常見食材 chip 時，把文字灌進輸入框並觸發查詢 |
| `_onChanged(raw)` | 更新 `_query`；空字串直接清空結果；非空則設定防抖計時器呼叫 `_run` |
| `_run(q)` | 呼叫 `DBHelper.searchFoodRef`，用 `_reqId` + `mounted` 雙重防呆後才 `setState` |
| `_pick(item)` | 呼叫 `widget.onPick`；成功加入 `_added` + 顯示成功 SnackBar；失敗顯示失敗 SnackBar |
| `_buildBody()` | 依「查詢是否為空 / 載入中 / 無結果 / 有結果」切換畫面 |
| `_subtitle(item)` | 組出「xxx kcal　蛋白 xg　碳水 xg　脂肪 xg　·　別名」字串 |
| `_Hint` | 私有 widget：置中圖示 + 文字，用於無結果狀態 |
| `_HighlightText` | 私有 widget：用 `RichText`/`TextSpan` 把命中關鍵字標色（淺藍、加粗），做法類似搜尋引擎結果高亮 |

#### `coming_soon_screen.dart` — `ComingSoonScreen`
「健身」分頁的佔位畫面，純顯示，無邏輯、無狀態。**目前 import 了 `fl_chart` 但沒有使用到**，可能是預留給未來的圖表功能。

---

### 2.5 `lib/utils/` — 共用邏輯與常數

#### `constants.dart`
| 名稱 | 說明 |
|---|---|
| `ElementColors` | 全 App 唯一色票來源：`background`（主背景深藍灰）、`cardBg`（卡片背景，比背景亮一階）、`accent`（強調色，所有按鈕/選取狀態）、`accentDim`（未選取用，比 accent 暗）、`lightUi`（高亮文字/小標）、`dayBg`/`dayBorder`（週曆用灰階） |
| `kGreyBoldText` / `kTitleText` | 共用 `TextStyle` |
| `segmentedStyleOnDark()` | 回傳 `ButtonStyle`，讓 `SegmentedButton` 在深色主題下「未選取」也維持可讀（用 `accentDim` + 淺藍字，而不是預設的偏黑配色），用於 Onboarding 的性別/目標選擇器 |

#### `exercise_data.dart`
| 名稱 | 說明 |
|---|---|
| `ExerciseIntensity(label, met)` | 同一運動的一種強度檔位，`met` 是代謝當量 |
| `ExercisePreset(name, intensities)` | 一種運動類型，含多檔強度；`defaultIntensity` 取中間那檔當預設 |
| `kExercisePresets` | `const` 12 種常見運動（跑步/快走/騎腳踏車/游泳/重量訓練/跳繩/橢圓機/登山健行/瑜伽/籃球/羽球/有氧舞蹈），MET 值引用自 *Compendium of Physical Activities (2011)* |
| `estimateExerciseKcal({met, minutes, weightKg})` | `kcal ≈ MET × 體重(kg) × 時間(小時)`；沒有體重資料（`weightKg == null`）時預設用 60kg |
| `WorkoutPlan(title, subtitle, items)` | 靜態文字課表 |
| `kWorkoutPlans` | `const` 3 個內建計畫（推拉腿三分化 / 全身 5×5 入門 / Zone 2 有氧） |

#### `nutrition_math.dart`
**全 App 唯一的營養計算核心**，刻意寫成不依賴 Flutter / DB，方便單獨寫單元測試。

| 名稱 | 說明 |
|---|---|
| `enum Sex { male, female }` | |
| `enum ActivityLevel { sedentary, light, moderate, active, veryActive }` | |
| `enum Goal { cut, maintain, bulk }` | |
| `ActivityLevelInfo.factor` | TDEE = BMR × 這個係數。**刻意比傳統 Mifflin 活動係數略低**，因為刻意運動已經在「運動」頁單獨記錄、消耗熱量再加回剩餘熱量，這裡只反映「日常非運動活動（NEAT）」，避免運動被算兩次 |
| `ActivityLevelInfo.label` | UI 顯示文字 |
| `GoalInfo.calorieFactor` | 目標熱量 = TDEE × 此係數（減脂 `0.85`／維持 `1.0`／增肌 `1.10`） |
| `GoalInfo.proteinPerKg` | 每公斤體重的蛋白質克數目標（減脂 `2.2`、維持 `1.8`、增肌 `2.0`——減脂時提高以保留肌肉） |
| `GoalInfo.label` | UI 顯示文字 |
| `NutritionTargets` | 資料容器：`bmr`、`tdee`（`double`）、`calories`/`proteinG`/`carbsG`/`fatG`（`int`） |
| `NutritionTargets.macroPercent` | getter，回傳 `(蛋白%, 碳水%, 脂肪%)` 的 record，用熱量占比換算（蛋白/碳水 4 kcal/g、脂肪 9 kcal/g），純顯示用 |
| `mifflinStJeorBmr({sex, weightKg, heightCm, age})` | Mifflin-St Jeor 公式：`10×體重 + 6.25×身高 − 5×年齡 + (男+5／女−161)` |
| `computeTargets({sex, weightKg, heightCm, age, activity, goal})` | **整條計算鏈的入口**：<br>1. `mifflinStJeorBmr` 算 BMR<br>2. `bmr × activity.factor` = TDEE<br>3. `tdee × goal.calorieFactor` 四捨五入 = 每日熱量目標<br>4. `goal.proteinPerKg × weightKg` 四捨五入 = 蛋白質目標(g)<br>5. 脂肪 = `max(熱量的25% ÷ 9, 0.8 × 體重)` 四捨五入——取較高者，確保荷爾蒙所需脂肪下限<br>6. 碳水 = `(熱量 − 蛋白質kcal − 脂肪kcal) ÷ 4`，並 `clamp` 下限為 0，避免熱量目標極低時碳水變負數 |

#### `scroll_behavior.dart`
| 名稱 | 說明 |
|---|---|
| `MyScrollBehavior` | 繼承 `MaterialScrollBehavior`，覆寫 `dragDevices` 加入 `mouse`、`trackpad`（預設只有 `touch`），讓桌面/DevicePreview 環境下滑鼠也能拖曳捲動畫面 |

---

### 2.6 `lib/widgets/home/`

#### `calories_info.dart`
| 名稱 | 說明 |
|---|---|
| `CaloriesFetch(remaining, consumed)` | **尚未設定個人資料**時的替代顯示（`_profile == null`），只顯示「剩餘熱量」「已攝取熱量」兩行文字 |
| `_CaloriesRow(label, value)` | 私有共用列 widget |

#### `daily_target_card.dart`
| 名稱 | 說明 |
|---|---|
| `DailyTargetCard(targets, consumed, burned, onEditProfile)` | 有個人資料後取代 `CaloriesFetch` 的主要卡片 |
| `_effectiveBudget` | getter：`targets.calories + burned`（把運動消耗加回預算） |
| `_remaining` | getter：`_effectiveBudget − consumed` |
| `build()` 內的 `progress` | `(consumed / effectiveBudget).clamp(0,1)`，驅動進度條 |
| `build()` 內的 `over` | `_remaining < 0`，超標時進度條變紅、文字改顯示「已超標 N」 |
| `onEditProfile` | 有給值才顯示「調整」按鈕，點了會導回 `OnboardingScreen` 編輯模式（由 `home_screen._editProfile` 提供） |
| `_Macro(label, grams)` | 私有 widget，顯示蛋白質/碳水/脂肪三個數字 |

#### `home_header.dart`
| 名稱 | 說明 |
|---|---|
| `HomeHeader(dateLabel)` | 頁首：上方留白、一個通知鈴鐺 `ElevatedButton`（`onPressed: () {}`，**目前是沒有作用的假按鈕**）、`dateLabel` 大標題文字 |

#### `streak_section.dart`
| 名稱 | 說明 |
|---|---|
| `StreakInfoRow(streakCount)` | 顯示「N 天連續記錄」；`streakCount == 0` 時改顯示鼓勵文字「記錄食物來開始連續紀錄」 |
| `FoodStreakSection(plans)` | 可展開/收合的「飲食計畫」區塊 |
| `_isExpanded` | 展開狀態旗標 |
| `build()` 內的 `containerHeight` | `_isExpanded` 為真時 120、否則 0，搭配 `AnimatedContainer` 做高度動畫；只有展開時才會實際 render `PlanCarousel`（收合時 child 為 `null`，省資源） |

#### `week_row.dart`
| 名稱 | 說明 |
|---|---|
| `WeekRow(today, weekDates, selectedIndex, onSelect)` | 一週 7 個可點選的日期圓圈 |
| `_dayLabels` | `const ['一','二','三','四','五','六','日']` |
| `_fillColor({isToday, isSelected, isPast})` | 決定圓圈填色優先序：選中且是今天 → `accent`；是今天但未選 → 淺灰；過去的日子 → 深灰；其餘（未來）→ 背景色 |
| `onSelect` | 點擊回呼，接到 `home_screen._selectDay` |

---

### 2.7 `lib/widgets/meals/`

#### `meal_card.dart` — `MealCard`
單一餐別（早餐/午餐/晚餐/宵夜/其他餐點）的卡片。

| 名稱 | 說明 |
|---|---|
| `widget.onFoodSelected` | `void Function(String foodName, int calories, double portion)`，選好食物（或手動輸入完）後呼叫，往上交給 `MealEntry` 轉接 |
| `widget.onManageFoodLibrary` | 「新增餐點」按鈕觸發，實際邏輯由 `home_screen._showAddFoodDialog` 提供 |
| `_manualNameController` / `_manualCaloriesController` | 手動輸入對話框用的 controller |
| `_iconForTitle(title)` | 依餐別標題（字串比對）回傳對應圖示（早餐=太陽、午餐=午餐圖示、晚餐=夜晚星星、宵夜=月亮，其他一律 `fastfood`） |
| `_showManualEntryDialog()` | 快速輸入「餐點庫沒有、臨時吃的」熱量；名稱留空時預設存為「自訂」；份量固定 `1.0` |
| `_showPortionDialog(food)` | +/-（每次 0.5）調整份數的對話框，確認時把 `(food.calories × portion)` 四捨五入回傳給 `onFoodSelected` |
| `_showFoodPicker()` | 底部彈出 `foodLibrary` 清單；點一項會先關閉此 sheet 再開 `_showPortionDialog`；底部另有「新增餐點」「手動輸入」兩個捷徑 |
| `build()` | 卡片主體：圖示 + 標題 + （若 >0）總熱量 + 「＋」按鈕；下方若有品項則用逗號串接顯示，份量不是 1 的會加註 `(xN)` |

#### `meal_entry.dart` — `MealEntry`
把 5 個 `MealCard` 組起來的**純轉接層**：把每張 `MealCard` 自己的 `onFoodSelected(foodName, calories, portion)` 補上 `meal.title`，轉呼叫成 `home_screen` 統一處理的 `MealFoodAdded onFoodAdded(mealTitle, foodName, calories, portion)` 簽名。沒有任何自己的狀態。

---

### 2.8 `lib/widgets/plans/`

#### `plan_carousel.dart` — `PlanCarousel`
飲食方案的橫向卡片輪播，**用倍數技巧模擬無限循環**（`PageView.builder` 原生不支援 loop）。

| 名稱 | 說明 |
|---|---|
| `_loopMultiplier` | `10000`，把 `itemCount` 乘大，讓使用者感覺可以無限往兩邊滑 |
| `_controller` | `viewportFraction: 0.6`（同時露出左右鄰卡一小部分），`initialPage` 用取模運算算到一個「落在資料中段、且對應到真正 index 1」的位置，確保一開始往左往右滑都有空間 |
| `build()` 內的 `index = rawIndex % plans.length` | 把巨大的虛擬 index 換算回真正的資料 index |
| `errorBuilder` | 圖片 asset 缺失時不顯示紅色錯誤畫面，改顯示方案標題文字（防禦性寫法） |
| `_showPlanDetail(context, plan)` | 用透明背景的 `showModalBottomSheet` 開 `PlanDetailSheet` |

#### `plan_detail_sheet.dart` — `PlanDetailSheet`
`DraggableScrollableSheet`（初始 0.6、範圍 0.3–0.9 螢幕高度）顯示方案標題、描述、`dietRules` 條列清單。`scrollController` 交給 sheet 本身控制，避免「拖動 sheet」跟「捲動內容」手勢互相打架。

---

## 3. 資料庫 Schema 速覽（`meals.db`，目前 version = 7）

| 資料表 | 主鍵 / 唯一鍵 | 用途 | 對應 Model |
|---|---|---|---|
| `meals` | `id` AUTOINCREMENT | 熱量異動的流水帳（append-only，非目前狀態） | 無獨立 model，直接用 Map |
| `foods` | `id` AUTOINCREMENT | 使用者自訂餐點庫模板 | `FoodItem` |
| `meal_foods` | `id` AUTOINCREMENT，`UNIQUE(date, meal_title, food_name)` | 某天某餐目前實際吃了哪些品項（現況表，可被覆蓋/刪除） | 無獨立 model，讀出後轉成 `MealFoodRecord` |
| `food_ref` | `id` AUTOINCREMENT，`ref_code` UNIQUE | TFDA 食品營養成分參考庫（唯讀，App 內建 seed） | `FoodRefItem` |
| `user_profile` | `id` CHECK(id=1) | 使用者個人資料（單列表） | `UserProfile` |
| `weight_log` | `date`（主鍵） | 每日體重歷史 | `WeightEntry` |
| `exercises` | `id` AUTOINCREMENT | 每日運動紀錄 | `ExerciseEntry` |

> 注意：`meals` 存的是「異動量」而非「目前總量」，真正代表現況的是 `meal_foods`；App 重新載入某天資料時是讀 `meal_foods` 重建畫面（見 `home_screen._loadMealsForDate`），`meals` 目前比較像是留給未來做「歷史統計/趨勢圖」的原始資料，尚未被讀取使用。

---

## 4. 端到端運作流程

### 流程 1：App 啟動 ／ 首次使用強制 Onboarding

```
main() → MyApp → RootShell(初始停在「日記」頁)
  → MyHomePage.initState()
       ├─ _loadFoodLibrary()         // 讀 foods 表
       ├─ _loadMealsForDate(今天)     // 讀 meal_foods + exercises（今天）
       └─ _loadProfileThenGate()
            → DBHelper.getUserProfile()
            → 若為 null：
                 WidgetsBinding.addPostFrameCallback
                 → Navigator.push(OnboardingScreen, fullscreenDialog: true)
                 → 使用者填 身高/體重/年齡/性別/活動量/目標
                    （每次打字都觸發 _previewTargets → computeTargets 即時預覽）
                 → 按「開始使用」→ _submit()
                      → DBHelper.saveUserProfile(profile)
                           → upsert user_profile
                           → logWeight(today, weightKg)  // 同步寫入體重歷史
                      → Navigator.pop(context, profile)
                 → MyHomePage: setState(_profile = profile)
                      → build() 改渲染 DailyTargetCard（取代 CaloriesFetch）
```

### 流程 2：搜尋食品 → 加入餐點庫

```
「搜尋食品」按鈕 → home_screen._openFoodSearch()
  → push FoodSearchScreen(onPick: ...)
  → 使用者輸入字 → _onChanged() → 180ms debounce → _run(q)
       → DBHelper.searchFoodRef(q)   // LIKE 查 food_ref，前綴命中優先排序
       → setState(_results = ...)    // _reqId 防止舊查詢覆蓋新結果
  → 使用者點一筆結果 → _pick(item) → widget.onPick(item)
       （呼叫端實作在 home_screen._openFoodSearch 內）
       → 把 FoodRefItem（每100g參考值）轉成新的 FoodItem
       → _addFoodToLibrary(food) → DBHelper.insertFood → foods 表新增一列
       → _loadFoodLibrary() 重新整理 _foodLibrary
  → FoodSearchScreen: _added.add(refCode) → 該列圖示變成「已加入」
```
> 這一步**只是把食物加進「餐點庫」模板**，還沒記錄到任何一餐的攝取量。

### 流程 3：從餐點庫挑食物記進某一餐（實際攝取記錄）

```
MealCard「＋」→ _showFoodPicker()（底部彈出 foodLibrary 清單）
  → 點一項 → 先關閉 sheet → _showPortionDialog(food)
  → +/- 調整份數（0.5 為單位）→ 確認
       → onFoodSelected(food.name, round(food.calories × portion), portion)
  → MealEntry 補上 meal.title
       → home_screen._onFoodAddedToMeal(mealTitle, foodName, calories, portion)
            ├─ 找出該 MealItem 內是否已有同名品項，算出 calorieDiff
            ├─ calorieDiff != 0 → DBHelper.insertMeal(異動量)     // 寫入 meals 流水帳
            ├─ portion <= 0 → DBHelper.deleteMealFood(...)        // 移除品項
            │  否則         → DBHelper.upsertMealFood(...)        // 現況表 REPLACE
            └─ setState：
                 ├─ 更新 _mealItems 內對應的 MealFoodRecord / meal.calories
                 └─ 更新連續記錄：_streakCount / _lastLoggedDate
                      （今天已記錄過 → 不變；昨天有記錄 → +1；
                        斷過 → 重置為 1）
  → UI 立即反映：MealCard 品項列表、DailyTargetCard 剩餘熱量與進度條
```

### 流程 4：記錄運動 → 反映到「日記」頁剩餘熱量（跨分頁通訊）

```
ExerciseScreen「記錄運動」FAB → _showRecordDialog()
  → 選 ExercisePreset + ExerciseIntensity + 輸入分鐘數
       → recalc()：kcal = estimateExerciseKcal(met, minutes, profile.weightKg ?? 60)
         （使用者若手動改過熱量欄位，kcalEditedManually=true，之後不再自動覆蓋）
  → 按「儲存」→ _addEntry(entry)
       ├─ DBHelper.insertExercise(entry)      // 寫入 exercises 表
       ├─ _load()                             // 重新讀今日運動列表與統計
       └─ widget.onChanged?.call()            // 通知外層
  → RootShell: onChanged 觸發 setState(_exerciseTick++)
  → MyHomePage 因為 prop（exerciseTick）改變而被 Flutter 呼叫 didUpdateWidget
       → 偵測到 exerciseTick 不同 → _loadBurnedForDate(目前選取日期)
            → DBHelper.getBurnedCaloriesByDate → 更新 _burnedCalories
  → DailyTargetCard 重新計算 _effectiveBudget(=targets.calories+burned) 與 _remaining
       → 剩餘熱量數字與進度條立即反映運動消耗
```
> 這是全 App 唯一的跨分頁（跨 `PageView` 子頁）狀態同步路徑，刻意透過 `RootShell` 當中介、用 widget prop 改變觸發 `didUpdateWidget`，而不是用全域狀態管理套件。也因此 `nutrition_math.dart` 的 `ActivityLevel.factor` 特意調低，避免運動熱量被「活動量係數」和「運動頁加回」重複計算兩次。

### 流程 5：切換週曆查看其他日期

```
WeekRow 圓圈被點 → onSelect(index) → home_screen._selectDay(index)
  → setState(_selectedIndex = index)
  → _loadMealsForDate(weekDates[index])
       ├─ 讀該日 meal_foods → 清空並重建 5 個 MealItem 的內容
       └─ _loadBurnedForDate(該日)
  → 畫面上的 MealCard、DailyTargetCard 全部改成顯示「選取日期」的資料
```
> `_streakCount`（連續記錄）**不會**因為切換查看歷史日期而重算——它只在「新增熱量到今天」時往前推進，且只存在記憶體、App 重啟即歸零，尚未做成依 `meal_foods` 歷史資料反推的版本。

### 流程 6：每日目標試算鏈（BMR → TDEE → 三大營養素）

```
UserProfile.targets（getter，每次存取都重新算）
  或 OnboardingScreen._previewTargets（打字即時預覽）
  → nutrition_math.computeTargets(sex, weightKg, heightCm, age, activity, goal)
       ├─ mifflinStJeorBmr()                         → BMR
       ├─ BMR × activity.factor                      → TDEE（僅反映日常非運動活動）
       ├─ TDEE × goal.calorieFactor（±%）             → 每日熱量目標
       ├─ goal.proteinPerKg × weightKg                → 蛋白質目標(g)
       ├─ max(熱量25%÷9, 0.8×weightKg)                → 脂肪目標(g)
       └─ (熱量 − 蛋白質kcal − 脂肪kcal) ÷ 4，clamp≥0  → 碳水目標(g)
  → 回傳 NutritionTargets，交給 DailyTargetCard 顯示
    （DailyTargetCard 另外把「運動消耗」加回預算，見流程 4）
```

---

## 5. 補充觀察（非必要修正項，僅供參考）

- **`_streakCount` 未持久化**：連續記錄天數只存在 `MyHomePage` 的 State 裡，App 重啟或切換分頁重建都會歸零，且只在「往前新增」時累計，沒有從 `meal_foods` 歷史資料回溯計算。
- **`meals` 表目前無人讀取**：`getMealsByDate` 沒有被任何畫面呼叫；真正驅動 UI 的是 `meal_foods`（現況表）。`meals` 看起來是為未來的歷史/趨勢功能預留的原始異動紀錄。
- **`HomeHeader` 的通知鈴鐺**（`home_header.dart`）目前 `onPressed: () {}`，尚未接上任何功能。
- **`ComingSoonScreen`** import 了 `fl_chart` 但未使用，「健身」分頁本身也還沒有實作內容。
- **日期字串格式**（`'yyyy-M-d'`，月日不補零）在 `db_helper.dart`、`home_screen.dart`、`exercise_screen.dart` 三處各自手刻拼接，目前保持一致所以能正確查詢，但若之後要改格式（例如補零成 `yyyy-MM-dd`）必須三處同步修改，否則會查不到資料。
- **`FoodItem.imagePath`** 欄位目前沒有任何畫面實際讀取顯示，是保留欄位。
