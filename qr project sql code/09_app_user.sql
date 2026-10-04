USE attendance_db;

DROP USER IF EXISTS 'attendance_app'@'localhost';
CREATE USER 'attendance_app'@'localhost' IDENTIFIED BY 'CHANGE_THIS_PASSWORD';

GRANT SELECT ON attendance_db.courses   TO 'attendance_app'@'localhost';
GRANT SELECT ON attendance_db.timetable TO 'attendance_app'@'localhost';
GRANT SELECT (lecturer_id, username, full_name) ON attendance_db.lecturers TO 'attendance_app'@'localhost';

GRANT EXECUTE ON PROCEDURE attendance_db.app_login                  TO 'attendance_app'@'localhost';
GRANT EXECUTE ON PROCEDURE attendance_db.app_change_password        TO 'attendance_app'@'localhost';
GRANT EXECUTE ON PROCEDURE attendance_db.app_open_session           TO 'attendance_app'@'localhost';
GRANT EXECUTE ON PROCEDURE attendance_db.app_mark_attendance        TO 'attendance_app'@'localhost';
GRANT EXECUTE ON PROCEDURE attendance_db.app_close_finished_sessions TO 'attendance_app'@'localhost';
GRANT EXECUTE ON PROCEDURE attendance_db.app_attended_today         TO 'attendance_app'@'localhost';
GRANT EXECUTE ON PROCEDURE attendance_db.app_my_history             TO 'attendance_app'@'localhost';
GRANT EXECUTE ON PROCEDURE attendance_db.app_session_list           TO 'attendance_app'@'localhost';
GRANT EXECUTE ON PROCEDURE attendance_db.app_lecturer_overview      TO 'attendance_app'@'localhost';

FLUSH PRIVILEGES;
