package app.example.demo.dto;

import java.time.LocalDate;
import java.util.List;

public class MealCreateRequest {
    
    // 實務上這通常會從登入的 Token 取出，為了方便先由前端帶入
    private Long userId; 
    
    private LocalDate recordDate;
    private String mealType; // BREAKFAST, LUNCH, DINNER, OTHER
    private List<FoodItemRequest> foodItems;

    // Getters and Setters
    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }
    public LocalDate getRecordDate() { return recordDate; }
    public void setRecordDate(LocalDate recordDate) { this.recordDate = recordDate; }
    public String getMealType() { return mealType; }
    public void setMealType(String mealType) { this.mealType = mealType; }
    public List<FoodItemRequest> getFoodItems() { return foodItems; }
    public void setFoodItems(List<FoodItemRequest> foodItems) { this.foodItems = foodItems; }
}
