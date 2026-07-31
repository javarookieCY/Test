package app.example.demo.service;

import app.example.demo.dto.FoodItemRequest;
import app.example.demo.dto.MealCreateRequest;
import app.example.demo.dto.MealResponse;
import app.example.demo.entity.FoodItemLog;
import app.example.demo.entity.MealLog;
import app.example.demo.entity.User;
import app.example.demo.repository.MealLogRepository;
import app.example.demo.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class MealService {

    private final MealLogRepository mealLogRepository;
    private final UserRepository userRepository;

    @Autowired
    public MealService(MealLogRepository mealLogRepository, UserRepository userRepository) {
        this.mealLogRepository = mealLogRepository;
        this.userRepository = userRepository;
    }

    @Transactional
    public MealResponse createMeal(MealCreateRequest request) {
        User user = userRepository.findById(request.getUserId())
            .orElseThrow(() -> new IllegalArgumentException("User not found with id: " + request.getUserId()));

        MealLog mealLog = new MealLog();
        mealLog.setUser(user);
        mealLog.setRecordDate(request.getRecordDate());
        mealLog.setMealType(request.getMealType());

        if (request.getFoodItems() != null) {
            for (FoodItemRequest itemReq : request.getFoodItems()) {
                FoodItemLog item = new FoodItemLog();
                item.setFoodName(itemReq.getFoodName());
                item.setCalories(itemReq.getCalories());
                item.setProtein(itemReq.getProtein());
                item.setCarbs(itemReq.getCarbs());
                item.setFat(itemReq.getFat());
                item.setFoodDatabaseId(itemReq.getFoodDatabaseId());
                
                // 透過 Helper 方法加入，自動設定雙向關聯
                mealLog.addFoodItem(item); 
            }
        }

        // 儲存 MealLog 時，因為設定了 CascadeType.ALL，FoodItemLog 也會跟著一起被儲存進資料庫
        MealLog savedMeal = mealLogRepository.save(mealLog);
        
        return new MealResponse(savedMeal);
    }
}
