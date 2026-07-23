package app.example.demo.dto;

import app.example.demo.entity.User;
import java.time.LocalDate;
import java.time.LocalDateTime;

public class UserResponse {

    private Long id;
    private String email;
    private String username;
    private String gender;
    private LocalDate dateOfBirth;
    private Float height;
    private LocalDateTime createdAt;

    // Default Constructor
    public UserResponse() {}

    // Constructor to convert from Entity to DTO
    public UserResponse(User user) {
        this.id = user.getId();
        this.email = user.getEmail();
        this.username = user.getUsername();
        this.gender = user.getGender();
        this.dateOfBirth = user.getDateOfBirth();
        this.height = user.getHeight();
        this.createdAt = user.getCreatedAt();
    }

    // Getters
    public Long getId() {
        return id;
    }

    public String getEmail() {
        return email;
    }

    public String getUsername() {
        return username;
    }

    public String getGender() {
        return gender;
    }

    public LocalDate getDateOfBirth() {
        return dateOfBirth;
    }

    public Float getHeight() {
        return height;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }
}
