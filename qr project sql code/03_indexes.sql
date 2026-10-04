USE attendance_db;

CREATE INDEX idx_enroll_course      ON enrollments(course_id);
CREATE INDEX idx_timetable_course   ON timetable(course_id);
CREATE INDEX idx_timetable_lecturer ON timetable(lecturer_id);
CREATE INDEX idx_sessions_date      ON lecture_sessions(session_date);
CREATE INDEX idx_attendance_student ON attendance_records(student_id);
CREATE INDEX idx_reports_student    ON monthly_reports(student_id);
