Create Table Users (
user_id Serial Primary KEY,
user_name Varchar(255) NOT NULL
);

Create Table Events (
event_id Serial Primary KEY,
event_time TIMESTAMP NOT NULL,
location VARCHAR(255) NOT NULL,
user_id INT,
FOREIGN KEY (user_id) REFERENCES Users(user_id)
);

Create Table Attendance (
attendance_id Serial Primary Key,
event_id INT,
user_id INT,
Foreign Key (event_id) References Events(event_id),
FOREIGN KEY (user_id) REFERENCES Users(user_id)
); 

