package app.example.demo.dto;

import app.example.demo.entity.MealLog;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

public class MealResponse {
    private Long id;
    private Long userId;
    private LocalDate recordDate;
    private String mealType;
    private Integer totalCalories;
    private List<FoodItemResponse> foodItems;
    private LocalDateTime createdAt;

    public MealResponse(MealLog mealLog) {
        this.id = mealLog.getId();
        this.userId = mealLog.getUser().getId();
        this.recordDate = mealLog.getRecordDate();
        this.mealType = mealLog.getMealType();
        this.createdAt = mealLog.getCreatedAt();
        
        if (mealLog.getFoodItems() != null) {
            this.foodItems = mealLog.getFoodItems().stream()
                .map(FoodItemResponse::new)
                .collect(Collectors.toList());
                
            this.totalCalories = mealLog.getFoodItems().stream()
                .mapToInt(item -> item.getCalories() != null ? item.getCalories() : 0)
                .sum();
        } else {
            this.totalCalories = 0;
        }
    }

    // Getters
    public Long getId() { return id; }
    public Long getUserId() { return userId; }
    public LocalDate getRecordDate() { return recordDate; }
    public String getMealType() { return mealType; }
    public Integer getTotalCalories() { return totalCalories; }
    public List<FoodItemResponse> getFoodItems() { return foodItems; }
    public LocalDateTime getCreatedAt() { return createdAt; }
}
