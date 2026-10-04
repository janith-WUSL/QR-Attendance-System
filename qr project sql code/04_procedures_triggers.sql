USE attendance_db;

DELIMITER $$

CREATE PROCEDURE sp_check_timetable_overlap(
    IN p_id INT, IN p_lecturer INT, IN p_day VARCHAR(10), IN p_start TIME, IN p_end TIME)
BEGIN
    IF EXISTS (SELECT 1 FROM timetable
               WHERE lecturer_id = p_lecturer
                 AND day_of_week = p_day
                 AND timetable_id <> IFNULL(p_id, 0)
                 AND start_time < p_end
                 AND p_start < end_time) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Lecturer already has an overlapping class at this time';
    END IF;
END$$

CREATE TRIGGER trg_timetable_ins BEFORE INSERT ON timetable FOR EACH ROW
BEGIN
    CALL sp_check_timetable_overlap(NULL, NEW.lecturer_id, NEW.day_of_week, NEW.start_time, NEW.end_time);
END$$

CREATE TRIGGER trg_timetable_upd BEFORE UPDATE ON timetable FOR EACH ROW
BEGIN
    CALL sp_check_timetable_overlap(OLD.timetable_id, NEW.lecturer_id, NEW.day_of_week, NEW.start_time, NEW.end_time);
END$$

CREATE TRIGGER trg_attendance_enrollment BEFORE INSERT ON attendance_records FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1
                   FROM lecture_sessions ls
                   JOIN timetable   t ON t.timetable_id = ls.timetable_id
                   JOIN enrollments e ON e.course_id    = t.course_id
                   WHERE ls.session_id = NEW.session_id
                     AND e.student_id  = NEW.student_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Student is not enrolled in the course of this session';
    END IF;
END$$

CREATE PROCEDURE generate_sessions(IN p_from DATE, IN p_to DATE)
BEGIN
    INSERT IGNORE INTO lecture_sessions (timetable_id, session_date, qr_token)
    WITH RECURSIVE days (dt) AS (
        SELECT p_from
        UNION ALL
        SELECT dt + INTERVAL 1 DAY FROM days WHERE dt < p_to
    )
    SELECT t.timetable_id, d.dt, SHA2(CONCAT(UUID(), RAND()), 256)
    FROM days d
    JOIN timetable t
      ON t.day_of_week = ELT(WEEKDAY(d.dt) + 1,
             'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday');

    SELECT ROW_COUNT() AS sessions_created;
END$$

CREATE PROCEDURE mark_attendance(
    IN p_qr_token VARCHAR(255), IN p_reg_no VARCHAR(20), IN p_enforce_time BOOLEAN)
main_block: BEGIN
    DECLARE v_session_id INT;
    DECLARE v_date       DATE;
    DECLARE v_course_id  INT;
    DECLARE v_start_t    TIME;
    DECLARE v_end_t      TIME;
    DECLARE v_student_id INT;
    DECLARE v_status     VARCHAR(10);
    DECLARE v_start      DATETIME;
    DECLARE v_end        DATETIME;
    DECLARE v_now        DATETIME;

    SET v_now = UTC_TIMESTAMP() + INTERVAL 330 MINUTE;

    SELECT ls.session_id, ls.session_date, t.course_id, t.start_time, t.end_time
      INTO v_session_id, v_date, v_course_id, v_start_t, v_end_t
      FROM lecture_sessions ls
      JOIN timetable t ON t.timetable_id = ls.timetable_id
     WHERE ls.qr_token = p_qr_token;

    IF v_session_id IS NULL THEN
        SELECT 'INVALID_QR' AS result; LEAVE main_block;
    END IF;

    SELECT student_id INTO v_student_id FROM students WHERE reg_no = p_reg_no;
    IF v_student_id IS NULL THEN
        SELECT 'STUDENT_NOT_FOUND' AS result; LEAVE main_block;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM enrollments
                   WHERE student_id = v_student_id AND course_id = v_course_id) THEN
        SELECT 'NOT_ENROLLED' AS result; LEAVE main_block;
    END IF;

    SET v_start = TIMESTAMP(v_date, v_start_t);
    SET v_end   = TIMESTAMP(v_date, v_end_t);

    IF p_enforce_time AND (v_now < v_start - INTERVAL 15 MINUTE OR v_now > v_end) THEN
        SELECT 'OUTSIDE_SESSION_TIME' AS result; LEAVE main_block;
    END IF;

    IF EXISTS (SELECT 1 FROM attendance_records
               WHERE session_id = v_session_id AND student_id = v_student_id) THEN
        SELECT 'ALREADY_MARKED' AS result; LEAVE main_block;
    END IF;

    SET v_status = IF(v_now > v_start + INTERVAL 15 MINUTE, 'LATE', 'PRESENT');

    INSERT INTO attendance_records (session_id, student_id, status, marked_time)
    VALUES (v_session_id, v_student_id, v_status, v_now);

    SELECT v_status AS result;
END$$

CREATE PROCEDURE close_session(IN p_session_id INT)
BEGIN
    INSERT IGNORE INTO attendance_records (session_id, student_id, status, marked_time)
    SELECT ls.session_id, e.student_id, 'ABSENT', NULL
    FROM lecture_sessions ls
    JOIN timetable   t ON t.timetable_id = ls.timetable_id
    JOIN enrollments e ON e.course_id    = t.course_id
    WHERE ls.session_id = p_session_id;

    SELECT ROW_COUNT() AS absent_rows_created;
END$$

CREATE PROCEDURE generate_monthly_report(IN p_month VARCHAR(7))
BEGIN
    INSERT INTO monthly_reports (student_id, course_id, month_year, attendance_percent)
    SELECT a.student_id, t.course_id, p_month,
           ROUND(100 * SUM(a.status IN ('PRESENT','LATE')) / COUNT(*), 2)
    FROM attendance_records a
    JOIN lecture_sessions ls ON ls.session_id  = a.session_id
    JOIN timetable        t  ON t.timetable_id = ls.timetable_id
    WHERE DATE_FORMAT(ls.session_date, '%Y-%m') = p_month
    GROUP BY a.student_id, t.course_id
    ON DUPLICATE KEY UPDATE attendance_percent = VALUES(attendance_percent);

    SELECT COUNT(*) AS reports_in_month FROM monthly_reports WHERE month_year = p_month;
END$$

DELIMITER ;
