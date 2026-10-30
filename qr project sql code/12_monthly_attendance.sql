USE attendance_db;

DROP PROCEDURE IF EXISTS app_my_monthly;
DROP PROCEDURE IF EXISTS app_lecturer_low_monthly;

DELIMITER $$

-- Student: per-course attendance % for one month (p_month = 'YYYY-MM').
-- Only lectures that have already finished are counted. PRESENT + LATE = attended.
CREATE PROCEDURE app_my_monthly(
    IN p_username VARCHAR(50), IN p_password VARCHAR(100), IN p_month VARCHAR(7))
BEGIN
    DECLARE v_state VARCHAR(10);
    DECLARE v_role  VARCHAR(10);
    DECLARE v_ref   INT;
    DECLARE v_must  TINYINT;
    DECLARE v_now   DATETIME;

    CALL sp_auth(p_username, p_password, 'STUDENT', v_state, v_role, v_ref, v_must);
    IF v_state <> 'OK' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'AUTH_FAILED';
    END IF;

    SET v_now = UTC_TIMESTAMP() + INTERVAL 330 MINUTE;

    SELECT c.course_code, c.course_name,
           COUNT(ls.session_id)                                  AS total_sessions,
           IFNULL(SUM(a.status IN ('PRESENT','LATE')), 0)        AS attended,
           IF(COUNT(ls.session_id) = 0, NULL,
              ROUND(100 * IFNULL(SUM(a.status IN ('PRESENT','LATE')), 0)
                        / COUNT(ls.session_id), 2))              AS percent
      FROM enrollments e
      JOIN courses   c ON c.course_id   = e.course_id
      JOIN timetable t ON t.course_id   = c.course_id
      LEFT JOIN lecture_sessions ls
             ON ls.timetable_id = t.timetable_id
            AND DATE_FORMAT(ls.session_date, '%Y-%m') = p_month
            AND TIMESTAMP(ls.session_date, t.end_time) < v_now
      LEFT JOIN attendance_records a
             ON a.session_id = ls.session_id AND a.student_id = v_ref
     WHERE e.student_id = v_ref
     GROUP BY c.course_id, c.course_code, c.course_name
     ORDER BY c.course_code;
END$$

-- Lecturer: students below 80% (in this lecturer's lectures) for one month.
CREATE PROCEDURE app_lecturer_low_monthly(
    IN p_username VARCHAR(50), IN p_password VARCHAR(100), IN p_month VARCHAR(7))
BEGIN
    DECLARE v_state VARCHAR(10);
    DECLARE v_role  VARCHAR(10);
    DECLARE v_ref   INT;
    DECLARE v_must  TINYINT;
    DECLARE v_now   DATETIME;

    CALL sp_auth(p_username, p_password, 'LECTURER', v_state, v_role, v_ref, v_must);
    IF v_state <> 'OK' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'AUTH_FAILED';
    END IF;

    SET v_now = UTC_TIMESTAMP() + INTERVAL 330 MINUTE;

    SELECT c.course_code, s.reg_no, s.name,
           COUNT(ls.session_id)                                  AS total_sessions,
           IFNULL(SUM(a.status IN ('PRESENT','LATE')), 0)        AS attended,
           ROUND(100 * IFNULL(SUM(a.status IN ('PRESENT','LATE')), 0)
                     / COUNT(ls.session_id), 2)                  AS percent
      FROM timetable t
      JOIN courses     c ON c.course_id  = t.course_id
      JOIN enrollments e ON e.course_id  = c.course_id
      JOIN students    s ON s.student_id = e.student_id
      JOIN lecture_sessions ls
        ON ls.timetable_id = t.timetable_id
       AND DATE_FORMAT(ls.session_date, '%Y-%m') = p_month
       AND TIMESTAMP(ls.session_date, t.end_time) < v_now
      LEFT JOIN attendance_records a
             ON a.session_id = ls.session_id AND a.student_id = s.student_id
     WHERE t.lecturer_id = v_ref
     GROUP BY c.course_id, c.course_code, s.student_id, s.reg_no, s.name
    HAVING COUNT(ls.session_id) > 0
       AND 100 * IFNULL(SUM(a.status IN ('PRESENT','LATE')), 0) / COUNT(ls.session_id) < 80
     ORDER BY c.course_code, percent, s.reg_no;
END$$

DELIMITER ;

GRANT EXECUTE ON PROCEDURE attendance_db.app_my_monthly           TO 'attendance_app'@'localhost';
GRANT EXECUTE ON PROCEDURE attendance_db.app_lecturer_low_monthly TO 'attendance_app'@'localhost';
FLUSH PRIVILEGES;
