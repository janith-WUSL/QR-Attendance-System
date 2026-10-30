USE attendance_db;

DROP PROCEDURE IF EXISTS app_lecturer_overview;

DELIMITER $$
CREATE PROCEDURE app_lecturer_overview(IN p_username VARCHAR(50), IN p_password VARCHAR(100))
BEGIN
    DECLARE v_state VARCHAR(10);
    DECLARE v_role  VARCHAR(10);
    DECLARE v_ref   INT;
    DECLARE v_must  TINYINT;

    CALL sp_auth(p_username, p_password, 'LECTURER', v_state, v_role, v_ref, v_must);
    IF v_state <> 'OK' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'AUTH_FAILED';
    END IF;

    SELECT ls.session_id, ls.timetable_id,
           DATE_FORMAT(ls.session_date, '%Y-%m-%d') AS session_date,
           c.course_code,
           DATE_FORMAT(t.start_time, '%H:%i') AS start_at,
           IFNULL(SUM(a.status IN ('PRESENT','LATE')), 0) AS attended,
           (SELECT COUNT(*) FROM enrollments e WHERE e.course_id = t.course_id) AS enrolled
      FROM lecture_sessions ls
      JOIN timetable t ON t.timetable_id = ls.timetable_id
      JOIN courses   c ON c.course_id    = t.course_id
      LEFT JOIN attendance_records a ON a.session_id = ls.session_id
     WHERE t.lecturer_id = v_ref
     GROUP BY ls.session_id, ls.timetable_id, ls.session_date, c.course_code, t.start_time, t.course_id
     ORDER BY ls.session_date DESC, t.start_time DESC
     LIMIT 30;
END$$
DELIMITER ;

GRANT EXECUTE ON PROCEDURE attendance_db.app_lecturer_overview TO 'attendance_app'@'localhost';
FLUSH PRIVILEGES;