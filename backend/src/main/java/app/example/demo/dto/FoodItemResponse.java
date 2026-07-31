package app.example.demo.dto;

import app.example.demo.entity.FoodItemLog;

public class FoodItemResponse {
    private Long id;
    private String foodName;
    private Integer calories;
    private Float protein;
    private Float carbs;
    private Float fat;

    public FoodItemResponse(FoodItemLog foodItem) {
        this.id = foodItem.getId();
        this.foodName = foodItem.getFoodName();
        this.calories = foodItem.getCalories();
        this.protein = foodItem.getProtein();
        this.carbs = foodItem.getCarbs();
        this.fat = foodItem.getFat();
    }

    // Getters
    public Long getId() { return id; }
    public String getFoodName() { return foodName; }
    public Integer getCalories() { return calories; }
    public Float getProtein() { return protein; }
    public Float getCarbs() { return carbs; }
    public Float getFat() { return fat; }
}
