package app.example.demo.service;

import app.example.demo.dto.UserCreateRequest;
import app.example.demo.dto.UserResponse;
import app.example.demo.entity.User;
import app.example.demo.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UserService {

    private final UserRepository userRepository;

    @Autowired
    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Transactional
    public UserResponse createUser(UserCreateRequest request) {
        // 檢查信箱是否已註冊
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new IllegalArgumentException("Email already exists: " + request.getEmail());
        }

        User user = new User();
        user.setEmail(request.getEmail());
        user.setUsername(request.getUsername());
        
        // 實務上這裡必須使用 BCrypt 或其他演算法進行密碼雜湊
        // 例如: user.setPasswordHash(passwordEncoder.encode(request.getPassword()));
        // 這裡暫時簡單存放 (不推薦)
        user.setPasswordHash(request.getPassword()); 
        
        user.setGender(request.getGender());
        user.setDateOfBirth(request.getDateOfBirth());
        user.setHeight(request.getHeight());

        User savedUser = userRepository.save(user);

        return new UserResponse(savedUser);
    }
}
