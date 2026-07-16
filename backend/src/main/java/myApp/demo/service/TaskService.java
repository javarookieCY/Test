package myApp.demo.service;

import myApp.demo.dto.TaskRequest;
import myApp.demo.dto.TaskResponse;
import java.util.List;

public interface TaskService {
    List<TaskResponse> getAllTasks();
    TaskResponse getTaskById(Long id);
    TaskResponse createTask(TaskRequest request);
    TaskResponse updateTask(Long id, TaskRequest request);
    void deleteTask(Long id);
}