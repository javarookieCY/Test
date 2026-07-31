package app.example.demo.dto;

public class FoodItemRequest {
    
    private String foodName;
    private Integer calories;
    private Float protein;
    private Float carbs;
    private Float fat;
    private Long foodDatabaseId; // 未來如果有食物庫，可以傳這個

    // Getters and Setters
    public String getFoodName() { return foodName; }
    public void setFoodName(String foodName) { this.foodName = foodName; }
    public Integer getCalories() { return calories; }
    public void setCalories(Integer calories) { this.calories = calories; }
    public Float getProtein() { return protein; }
    public void setProtein(Float protein) { this.protein = protein; }
    public Float getCarbs() { return carbs; }
    public void setCarbs(Float carbs) { this.carbs = carbs; }
    public Float getFat() { return fat; }
    public void setFat(Float fat) { this.fat = fat; }
    public Long getFoodDatabaseId() { return foodDatabaseId; }
    public void setFoodDatabaseId(Long foodDatabaseId) { this.foodDatabaseId = foodDatabaseId; }
}
