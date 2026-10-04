USE attendance_db;

CALL generate_sessions('2026-09-01', '2026-09-30');

CREATE TEMPORARY TABLE tmp_att AS
SELECT ls.session_id, e.student_id, ls.session_date, t.start_time, RAND() AS r
FROM lecture_sessions ls
JOIN timetable   t ON t.timetable_id = ls.timetable_id
JOIN enrollments e ON e.course_id    = t.course_id;

INSERT INTO attendance_records (session_id, student_id, status, marked_time)
SELECT session_id, student_id,
       CASE WHEN r < 0.80 THEN 'PRESENT' WHEN r < 0.90 THEN 'LATE' ELSE 'ABSENT' END,
       CASE WHEN r >= 0.90 THEN NULL
            ELSE TIMESTAMP(session_date, start_time) + INTERVAL FLOOR(r * 20) MINUTE END
FROM tmp_att;

DROP TEMPORARY TABLE tmp_att;

CALL generate_monthly_report('2026-09');
