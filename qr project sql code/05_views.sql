USE attendance_db;

CREATE VIEW v_timetable_full AS
SELECT t.timetable_id, t.day_of_week, t.start_time, t.end_time,
       c.course_code, c.course_name, t.session_type, t.group_name,
       l.full_name AS lecturer
FROM timetable t
JOIN courses   c ON c.course_id   = t.course_id
JOIN lecturers l ON l.lecturer_id = t.lecturer_id
ORDER BY FIELD(t.day_of_week,'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'),
         t.start_time;

CREATE VIEW v_session_summary AS
SELECT ls.session_id, ls.session_date, c.course_code, t.session_type,
       t.start_time, t.end_time, ls.qr_token,
       COALESCE(SUM(a.status = 'PRESENT'), 0) AS present_count,
       COALESCE(SUM(a.status = 'LATE'),    0) AS late_count,
       COALESCE(SUM(a.status = 'ABSENT'),  0) AS absent_count
FROM lecture_sessions ls
JOIN timetable t ON t.timetable_id = ls.timetable_id
JOIN courses   c ON c.course_id    = t.course_id
LEFT JOIN attendance_records a ON a.session_id = ls.session_id
GROUP BY ls.session_id, ls.session_date, c.course_code, t.session_type,
         t.start_time, t.end_time, ls.qr_token;

CREATE VIEW v_student_course_attendance AS
SELECT s.student_id, s.reg_no, s.name, c.course_id, c.course_code,
       COUNT(*)                                        AS total_sessions,
       SUM(a.status IN ('PRESENT','LATE'))             AS attended,
       ROUND(100 * SUM(a.status IN ('PRESENT','LATE')) / COUNT(*), 2) AS attendance_percent
FROM attendance_records a
JOIN students         s  ON s.student_id   = a.student_id
JOIN lecture_sessions ls ON ls.session_id  = a.session_id
JOIN timetable        t  ON t.timetable_id = ls.timetable_id
JOIN courses          c  ON c.course_id    = t.course_id
GROUP BY s.student_id, s.reg_no, s.name, c.course_id, c.course_code;

CREATE VIEW v_low_attendance AS
SELECT * FROM v_student_course_attendance
WHERE attendance_percent < 80;
