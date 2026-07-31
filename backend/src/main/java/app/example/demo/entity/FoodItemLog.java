package app.example.demo.entity;

import jakarta.persistence.*;

@Entity
@Table(name = "food_item_logs")
public class FoodItemLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "meal_log_id", nullable = false)
    private MealLog mealLog;

    @Column(nullable = false)
    private String foodName;

    private Integer calories;
    private Float protein;
    private Float carbs;
    private Float fat;

    // 未來擴充：若從食物資料庫選取，可以存下那個資料庫的 ID
    private Long foodDatabaseId;

    public FoodItemLog() {}

    // Getters and Setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public MealLog getMealLog() {
        return mealLog;
    }

    public void setMealLog(MealLog mealLog) {
        this.mealLog = mealLog;
    }

    public String getFoodName() {
        return foodName;
    }

    public void setFoodName(String foodName) {
        this.foodName = foodName;
    }

    public Integer getCalories() {
        return calories;
    }

    public void setCalories(Integer calories) {
        this.calories = calories;
    }

    public Float getProtein() {
        return protein;
    }

    public void setProtein(Float protein) {
        this.protein = protein;
    }

    public Float getCarbs() {
        return carbs;
    }

    public void setCarbs(Float carbs) {
        this.carbs = carbs;
    }

    public Float getFat() {
        return fat;
    }

    public void setFat(Float fat) {
        this.fat = fat;
    }

    public Long getFoodDatabaseId() {
        return foodDatabaseId;
    }

    public void setFoodDatabaseId(Long foodDatabaseId) {
        this.foodDatabaseId = foodDatabaseId;
    }
}
