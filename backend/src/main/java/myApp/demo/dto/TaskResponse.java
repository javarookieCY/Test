package myApp.demo.dto;

public class TaskResponse {
    private final Long id;
    private final String title;
    private final String description;
    private final boolean completed;

    public TaskResponse(Long id, String title, String description, boolean completed) {
        this.id = id;
        this.title = title;
        this.description = description;
        this.completed = completed;
    }

    // getters
    public Long getId() { return id; }
    public String getTitle() { return title; }
    public String getDescription() { return description; }
    public boolean isCompleted() { return completed; }
}