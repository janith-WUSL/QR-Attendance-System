USE attendance_db;

DROP PROCEDURE IF EXISTS app_manual_mark;
DROP PROCEDURE IF EXISTS app_session_list;

DELIMITER $$

CREATE PROCEDURE app_manual_mark(
    IN p_username VARCHAR(50), IN p_password VARCHAR(100),
    IN p_session INT, IN p_reg_no VARCHAR(20), IN p_reason VARCHAR(255))
main_block: BEGIN
    DECLARE v_state   VARCHAR(10);
    DECLARE v_role    VARCHAR(10);
    DECLARE v_ref     INT;
    DECLARE v_must    TINYINT;
    DECLARE v_now     DATETIME;
    DECLARE v_course  INT;
    DECLARE v_student INT;
    DECLARE v_record  INT;
    DECLARE v_status  VARCHAR(10);

    CALL sp_auth(p_username, p_password, 'LECTURER', v_state, v_role, v_ref, v_must);
    IF v_state <> 'OK' THEN
        SELECT 'AUTH_FAILED' AS result; LEAVE main_block;
    END IF;

    SELECT t.course_id INTO v_course
      FROM lecture_sessions ls
      JOIN timetable t ON t.timetable_id = ls.timetable_id
     WHERE ls.session_id = p_session AND t.lecturer_id = v_ref;
    IF v_course IS NULL THEN
        SELECT 'NOT_YOUR_SESSION' AS result; LEAVE main_block;
    END IF;

    IF p_reason IS NULL OR CHAR_LENGTH(TRIM(p_reason)) < 3 THEN
        SELECT 'REASON_REQUIRED' AS result; LEAVE main_block;
    END IF;

    SELECT student_id INTO v_student FROM students WHERE reg_no = p_reg_no;
    IF v_student IS NULL THEN
        SELECT 'STUDENT_NOT_FOUND' AS result; LEAVE main_block;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM enrollments WHERE student_id = v_student AND course_id = v_course) THEN
        SELECT 'NOT_ENROLLED' AS result; LEAVE main_block;
    END IF;

    SET v_now = UTC_TIMESTAMP() + INTERVAL 330 MINUTE;

    SELECT record_id, status INTO v_record, v_status
      FROM attendance_records
     WHERE session_id = p_session AND student_id = v_student;

    IF v_record IS NOT NULL THEN
        IF v_status = 'ABSENT' THEN
            UPDATE attendance_records
               SET status = 'PRESENT', marked_time = v_now,
                   manual_reason = TRIM(p_reason), marked_by = v_ref
             WHERE record_id = v_record;
            SELECT 'OK' AS result;
        ELSE
            SELECT 'ALREADY_MARKED' AS result;
        END IF;
        LEAVE main_block;
    END IF;

    INSERT INTO attendance_records (session_id, student_id, status, marked_time, manual_reason, marked_by)
    VALUES (p_session, v_student, 'PRESENT', v_now, TRIM(p_reason), v_ref);

    SELECT 'OK' AS result;
END$$

CREATE PROCEDURE app_session_list(
    IN p_username VARCHAR(50), IN p_password VARCHAR(100), IN p_session INT)
BEGIN
    DECLARE v_state VARCHAR(10);
    DECLARE v_role  VARCHAR(10);
    DECLARE v_ref   INT;
    DECLARE v_must  TINYINT;

    CALL sp_auth(p_username, p_password, 'LECTURER', v_state, v_role, v_ref, v_must);
    IF v_state <> 'OK' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'AUTH_FAILED';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM lecture_sessions ls
                   JOIN timetable t ON t.timetable_id = ls.timetable_id
                   WHERE ls.session_id = p_session AND t.lecturer_id = v_ref) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'NOT_YOUR_SESSION';
    END IF;

    SELECT s.reg_no, s.name,
           IFNULL(a.status, 'NOT_MARKED') AS status,
           DATE_FORMAT(a.marked_time, '%H:%i') AS marked_at,
           a.manual_reason AS reason
      FROM lecture_sessions ls
      JOIN timetable   t ON t.timetable_id = ls.timetable_id
      JOIN enrollments e ON e.course_id    = t.course_id
      JOIN students    s ON s.student_id   = e.student_id
      LEFT JOIN attendance_records a ON a.session_id = ls.session_id AND a.student_id = s.student_id
     WHERE ls.session_id = p_session
     ORDER BY s.reg_no;
END$$

DELIMITER ;

GRANT EXECUTE ON PROCEDURE attendance_db.app_manual_mark       TO 'attendance_app'@'localhost';
GRANT EXECUTE ON PROCEDURE attendance_db.app_session_list      TO 'attendance_app'@'localhost';
GRANT EXECUTE ON PROCEDURE attendance_db.app_lecturer_overview TO 'attendance_app'@'localhost';
FLUSH PRIVILEGES;