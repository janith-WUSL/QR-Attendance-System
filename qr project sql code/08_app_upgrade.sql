USE attendance_db;

DROP PROCEDURE IF EXISTS tmp_upgrade;
DELIMITER $$
CREATE PROCEDURE tmp_upgrade()
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS
                   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'timetable' AND COLUMN_NAME = 'venue') THEN
        ALTER TABLE timetable ADD COLUMN venue VARCHAR(50) NOT NULL DEFAULT 'N3-01';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS
                   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'lecture_sessions' AND COLUMN_NAME = 'qr_expires') THEN
        ALTER TABLE lecture_sessions ADD COLUMN qr_expires DATETIME NULL;
    END IF;
END$$
DELIMITER ;
CALL tmp_upgrade();
DROP PROCEDURE tmp_upgrade;

DROP TABLE IF EXISTS user_accounts;
CREATE TABLE user_accounts (
    account_id      INT AUTO_INCREMENT PRIMARY KEY,
    role            VARCHAR(10)  NOT NULL,
    ref_id          INT          NOT NULL,
    username        VARCHAR(50)  NOT NULL UNIQUE,
    salt            VARCHAR(32)  NOT NULL,
    password_hash   VARCHAR(64)  NOT NULL,
    must_change     TINYINT      NOT NULL DEFAULT 1,
    failed_attempts INT          NOT NULL DEFAULT 0,
    locked_until    DATETIME     NULL,
    UNIQUE KEY uq_account_ref (role, ref_id),
    CONSTRAINT chk_account_role CHECK (role IN ('STUDENT','LECTURER'))
) ENGINE=InnoDB;

INSERT INTO user_accounts (role, ref_id, username, salt, password_hash)
SELECT 'STUDENT', student_id, reg_no, SUBSTRING(SHA2(CONCAT(UUID(), RAND()), 256), 1, 32), '' FROM students;

INSERT INTO user_accounts (role, ref_id, username, salt, password_hash)
SELECT 'LECTURER', lecturer_id, username, SUBSTRING(SHA2(CONCAT(UUID(), RAND()), 256), 1, 32), '' FROM lecturers;

UPDATE user_accounts SET password_hash = SHA2(CONCAT(salt, 'ChangeMe@123'), 256) WHERE account_id > 0;

DROP PROCEDURE IF EXISTS sp_auth;
DROP PROCEDURE IF EXISTS app_login;
DROP PROCEDURE IF EXISTS app_change_password;
DROP PROCEDURE IF EXISTS app_open_session;
DROP PROCEDURE IF EXISTS app_mark_attendance;
DROP PROCEDURE IF EXISTS app_close_finished_sessions;
DROP PROCEDURE IF EXISTS app_attended_today;
DROP PROCEDURE IF EXISTS app_my_history;
DROP PROCEDURE IF EXISTS app_session_list;
DROP PROCEDURE IF EXISTS app_lecturer_overview;

DELIMITER $$

CREATE PROCEDURE sp_auth(
    IN  p_username VARCHAR(50), IN p_password VARCHAR(100), IN p_role VARCHAR(10),
    OUT o_state VARCHAR(10), OUT o_role VARCHAR(10), OUT o_ref INT, OUT o_must TINYINT)
BEGIN
    DECLARE v_id     INT;
    DECLARE v_salt   VARCHAR(32);
    DECLARE v_hash   VARCHAR(64);
    DECLARE v_fail   INT;
    DECLARE v_locked DATETIME;
    DECLARE v_now    DATETIME;

    SET v_now   = UTC_TIMESTAMP() + INTERVAL 330 MINUTE;
    SET o_state = 'INVALID';
    SET o_role  = NULL;
    SET o_ref   = NULL;
    SET o_must  = 0;

    SELECT account_id, salt, password_hash, failed_attempts, locked_until, role, ref_id, must_change
      INTO v_id, v_salt, v_hash, v_fail, v_locked, o_role, o_ref, o_must
      FROM user_accounts
     WHERE username = p_username AND (p_role IS NULL OR role = p_role);

    IF v_id IS NOT NULL THEN
        IF v_locked IS NOT NULL AND v_locked > v_now THEN
            SET o_state = 'LOCKED';
        ELSEIF v_hash = SHA2(CONCAT(v_salt, p_password), 256) THEN
            SET o_state = 'OK';
            UPDATE user_accounts SET failed_attempts = 0, locked_until = NULL WHERE account_id = v_id;
        ELSE
            UPDATE user_accounts
               SET failed_attempts = IF(v_fail >= 4, 0, v_fail + 1),
                   locked_until    = IF(v_fail >= 4, v_now + INTERVAL 5 MINUTE, NULL)
             WHERE account_id = v_id;
        END IF;
    END IF;

    IF o_state <> 'OK' THEN
        SET o_role = NULL;
        SET o_ref  = NULL;
        SET o_must = 0;
    END IF;
END$$

CREATE PROCEDURE app_login(IN p_username VARCHAR(50), IN p_password VARCHAR(100))
BEGIN
    DECLARE v_state VARCHAR(10);
    DECLARE v_role  VARCHAR(10);
    DECLARE v_ref   INT;
    DECLARE v_must  TINYINT;
    DECLARE v_name  VARCHAR(150) DEFAULT NULL;

    CALL sp_auth(p_username, p_password, NULL, v_state, v_role, v_ref, v_must);

    IF v_state = 'OK' THEN
        IF v_role = 'STUDENT' THEN
            SELECT name INTO v_name FROM students WHERE student_id = v_ref;
        ELSE
            SELECT full_name INTO v_name FROM lecturers WHERE lecturer_id = v_ref;
        END IF;
    END IF;

    SELECT v_state AS result, v_role AS role, v_ref AS ref_id, v_name AS display_name, v_must AS must_change;
END$$

CREATE PROCEDURE app_change_password(
    IN p_username VARCHAR(50), IN p_old VARCHAR(100), IN p_new VARCHAR(100))
BEGIN
    DECLARE v_state VARCHAR(10);
    DECLARE v_role  VARCHAR(10);
    DECLARE v_ref   INT;
    DECLARE v_must  TINYINT;
    DECLARE v_salt  VARCHAR(32);

    CALL sp_auth(p_username, p_old, NULL, v_state, v_role, v_ref, v_must);

    IF v_state = 'LOCKED' THEN
        SELECT 'LOCKED' AS result;
    ELSEIF v_state <> 'OK' THEN
        SELECT 'BAD_PASSWORD' AS result;
    ELSEIF CHAR_LENGTH(p_new) < 8 THEN
        SELECT 'TOO_SHORT' AS result;
    ELSEIF BINARY p_new = BINARY p_old THEN
        SELECT 'SAME' AS result;
    ELSE
        SET v_salt = SUBSTRING(SHA2(CONCAT(UUID(), RAND()), 256), 1, 32);
        UPDATE user_accounts
           SET salt = v_salt,
               password_hash = SHA2(CONCAT(v_salt, p_new), 256),
               must_change = 0
         WHERE username = p_username;
        SELECT 'OK' AS result;
    END IF;
END$$

CREATE PROCEDURE app_open_session(
    IN p_username VARCHAR(50), IN p_password VARCHAR(100), IN p_tt INT)
main_block: BEGIN
    DECLARE v_state   VARCHAR(10);
    DECLARE v_role    VARCHAR(10);
    DECLARE v_ref     INT;
    DECLARE v_must    TINYINT;
    DECLARE v_now     DATETIME;
    DECLARE v_today   DATE;
    DECLARE v_lec     INT;
    DECLARE v_day     VARCHAR(10);
    DECLARE v_start   TIME;
    DECLARE v_end     TIME;
    DECLARE v_session INT;
    DECLARE v_token   VARCHAR(20);
    DECLARE v_valid   INT DEFAULT 30;

    CALL sp_auth(p_username, p_password, 'LECTURER', v_state, v_role, v_ref, v_must);
    IF v_state <> 'OK' THEN
        SELECT 'AUTH_FAILED' AS result, NULL AS session_id, NULL AS token, NULL AS valid_seconds;
        LEAVE main_block;
    END IF;

    SET v_now   = UTC_TIMESTAMP() + INTERVAL 330 MINUTE;
    SET v_today = DATE(v_now);

    SELECT lecturer_id, day_of_week, start_time, end_time
      INTO v_lec, v_day, v_start, v_end
      FROM timetable WHERE timetable_id = p_tt;

    IF v_lec IS NULL OR v_lec <> v_ref THEN
        SELECT 'NOT_YOUR_LECTURE' AS result, NULL AS session_id, NULL AS token, NULL AS valid_seconds;
        LEAVE main_block;
    END IF;

    IF v_day <> ELT(WEEKDAY(v_today) + 1, 'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday') THEN
        SELECT 'WRONG_DAY' AS result, NULL AS session_id, NULL AS token, NULL AS valid_seconds;
        LEAVE main_block;
    END IF;

    IF v_now < TIMESTAMP(v_today, v_start) - INTERVAL 15 MINUTE OR v_now > TIMESTAMP(v_today, v_end) THEN
        SELECT 'OUTSIDE_TIME' AS result, NULL AS session_id, NULL AS token, NULL AS valid_seconds;
        LEAVE main_block;
    END IF;

    SET v_token = UPPER(SUBSTRING(MD5(CONCAT(UUID(), RAND())), 1, 10));

    INSERT INTO lecture_sessions (timetable_id, session_date, qr_token, qr_expires)
    VALUES (p_tt, v_today, v_token, v_now + INTERVAL v_valid SECOND)
    ON DUPLICATE KEY UPDATE qr_token = VALUES(qr_token), qr_expires = VALUES(qr_expires);

    SELECT session_id INTO v_session
      FROM lecture_sessions WHERE timetable_id = p_tt AND session_date = v_today;

    SELECT 'OK' AS result, v_session AS session_id, v_token AS token, v_valid AS valid_seconds;
END$$

CREATE PROCEDURE app_mark_attendance(
    IN p_username VARCHAR(50), IN p_password VARCHAR(100), IN p_token VARCHAR(255), IN p_tt INT)
main_block: BEGIN
    DECLARE v_state   VARCHAR(10);
    DECLARE v_role    VARCHAR(10);
    DECLARE v_ref     INT;
    DECLARE v_must    TINYINT;
    DECLARE v_now     DATETIME;
    DECLARE v_session INT;
    DECLARE v_date    DATE;
    DECLARE v_expires DATETIME;
    DECLARE v_tt      INT;
    DECLARE v_course  INT;
    DECLARE v_start_t TIME;
    DECLARE v_end_t   TIME;
    DECLARE v_start   DATETIME;
    DECLARE v_end     DATETIME;
    DECLARE v_status  VARCHAR(10);

    CALL sp_auth(p_username, p_password, 'STUDENT', v_state, v_role, v_ref, v_must);
    IF v_state <> 'OK' THEN
        SELECT 'AUTH_FAILED' AS result, NULL AS marked_time;
        LEAVE main_block;
    END IF;

    SET v_now = UTC_TIMESTAMP() + INTERVAL 330 MINUTE;

    SELECT ls.session_id, ls.session_date, ls.qr_expires, t.timetable_id, t.course_id, t.start_time, t.end_time
      INTO v_session, v_date, v_expires, v_tt, v_course, v_start_t, v_end_t
      FROM lecture_sessions ls
      JOIN timetable t ON t.timetable_id = ls.timetable_id
     WHERE ls.qr_token = p_token;

    IF v_session IS NULL THEN
        SELECT 'INVALID_QR' AS result, NULL AS marked_time; LEAVE main_block;
    END IF;
    IF v_tt <> p_tt THEN
        SELECT 'WRONG_LECTURE' AS result, NULL AS marked_time; LEAVE main_block;
    END IF;
    IF v_expires IS NULL OR v_now > v_expires THEN
        SELECT 'QR_EXPIRED' AS result, NULL AS marked_time; LEAVE main_block;
    END IF;
    IF v_date <> DATE(v_now) THEN
        SELECT 'WRONG_DAY' AS result, NULL AS marked_time; LEAVE main_block;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM enrollments WHERE student_id = v_ref AND course_id = v_course) THEN
        SELECT 'NOT_ENROLLED' AS result, NULL AS marked_time; LEAVE main_block;
    END IF;

    SET v_start = TIMESTAMP(v_date, v_start_t);
    SET v_end   = TIMESTAMP(v_date, v_end_t);

    IF v_now < v_start - INTERVAL 15 MINUTE OR v_now > v_end THEN
        SELECT 'OUTSIDE_TIME' AS result, NULL AS marked_time; LEAVE main_block;
    END IF;
    IF EXISTS (SELECT 1 FROM attendance_records WHERE session_id = v_session AND student_id = v_ref) THEN
        SELECT 'ALREADY_MARKED' AS result, NULL AS marked_time; LEAVE main_block;
    END IF;

    SET v_status = IF(v_now > v_start + INTERVAL 15 MINUTE, 'LATE', 'PRESENT');

    INSERT INTO attendance_records (session_id, student_id, status, marked_time)
    VALUES (v_session, v_ref, v_status, v_now);

    SELECT v_status AS result, DATE_FORMAT(v_now, '%Y-%m-%d %H:%i:%s') AS marked_time;
END$$

CREATE PROCEDURE app_close_finished_sessions(IN p_username VARCHAR(50), IN p_password VARCHAR(100))
main_block: BEGIN
    DECLARE v_state VARCHAR(10);
    DECLARE v_role  VARCHAR(10);
    DECLARE v_ref   INT;
    DECLARE v_must  TINYINT;
    DECLARE v_now   DATETIME;

    CALL sp_auth(p_username, p_password, 'LECTURER', v_state, v_role, v_ref, v_must);
    IF v_state <> 'OK' THEN
        SELECT 0 AS closed;
        LEAVE main_block;
    END IF;

    SET v_now = UTC_TIMESTAMP() + INTERVAL 330 MINUTE;

    INSERT IGNORE INTO attendance_records (session_id, student_id, status, marked_time)
    SELECT ls.session_id, e.student_id, 'ABSENT', NULL
      FROM lecture_sessions ls
      JOIN timetable   t ON t.timetable_id = ls.timetable_id
      JOIN enrollments e ON e.course_id    = t.course_id
     WHERE t.lecturer_id = v_ref
       AND TIMESTAMP(ls.session_date, t.end_time) < v_now;

    SELECT ROW_COUNT() AS closed;
END$$

CREATE PROCEDURE app_attended_today(
    IN p_username VARCHAR(50), IN p_password VARCHAR(100), IN p_tt INT, IN p_date DATE)
BEGIN
    DECLARE v_state VARCHAR(10);
    DECLARE v_role  VARCHAR(10);
    DECLARE v_ref   INT;
    DECLARE v_must  TINYINT;

    CALL sp_auth(p_username, p_password, 'STUDENT', v_state, v_role, v_ref, v_must);
    IF v_state <> 'OK' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'AUTH_FAILED';
    END IF;

    SELECT COUNT(*) AS attended
      FROM attendance_records a
      JOIN lecture_sessions ls ON ls.session_id = a.session_id
     WHERE ls.timetable_id = p_tt
       AND ls.session_date = p_date
       AND a.student_id    = v_ref
       AND a.status IN ('PRESENT','LATE');
END$$

CREATE PROCEDURE app_my_history(IN p_username VARCHAR(50), IN p_password VARCHAR(100))
BEGIN
    DECLARE v_state VARCHAR(10);
    DECLARE v_role  VARCHAR(10);
    DECLARE v_ref   INT;
    DECLARE v_must  TINYINT;

    CALL sp_auth(p_username, p_password, 'STUDENT', v_state, v_role, v_ref, v_must);
    IF v_state <> 'OK' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'AUTH_FAILED';
    END IF;

    SELECT DATE_FORMAT(ls.session_date, '%Y-%m-%d') AS session_date,
           c.course_code, c.course_name,
           DATE_FORMAT(a.marked_time, '%H:%i') AS marked_at,
           a.status
      FROM attendance_records a
      JOIN lecture_sessions ls ON ls.session_id  = a.session_id
      JOIN timetable        t  ON t.timetable_id = ls.timetable_id
      JOIN courses          c  ON c.course_id    = t.course_id
     WHERE a.student_id = v_ref
     ORDER BY ls.session_date DESC, t.start_time DESC
     LIMIT 100;
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
           DATE_FORMAT(a.marked_time, '%H:%i') AS marked_at
      FROM lecture_sessions ls
      JOIN timetable   t ON t.timetable_id = ls.timetable_id
      JOIN enrollments e ON e.course_id    = t.course_id
      JOIN students    s ON s.student_id   = e.student_id
      LEFT JOIN attendance_records a ON a.session_id = ls.session_id AND a.student_id = s.student_id
     WHERE ls.session_id = p_session
     ORDER BY s.reg_no;
END$$

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

    SELECT DATE_FORMAT(ls.session_date, '%Y-%m-%d') AS session_date,
           c.course_code,
           DATE_FORMAT(t.start_time, '%H:%i') AS start_at,
           IFNULL(SUM(a.status IN ('PRESENT','LATE')), 0) AS attended,
           (SELECT COUNT(*) FROM enrollments e WHERE e.course_id = t.course_id) AS enrolled
      FROM lecture_sessions ls
      JOIN timetable t ON t.timetable_id = ls.timetable_id
      JOIN courses   c ON c.course_id    = t.course_id
      LEFT JOIN attendance_records a ON a.session_id = ls.session_id
     WHERE t.lecturer_id = v_ref
     GROUP BY ls.session_id, ls.session_date, c.course_code, t.start_time, t.course_id
     ORDER BY ls.session_date DESC, t.start_time DESC
     LIMIT 20;
END$$

DELIMITER ;
