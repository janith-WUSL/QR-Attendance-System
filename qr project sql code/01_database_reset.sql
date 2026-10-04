CREATE DATABASE IF NOT EXISTS attendance_db
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE attendance_db;

SET FOREIGN_KEY_CHECKS = 0;
DROP VIEW  IF EXISTS v_low_attendance;
DROP VIEW  IF EXISTS v_student_course_attendance;
DROP VIEW  IF EXISTS v_session_summary;
DROP VIEW  IF EXISTS v_timetable_full;
DROP TABLE IF EXISTS attendance_records;
DROP TABLE IF EXISTS lecture_sessions;
DROP TABLE IF EXISTS monthly_reports;
DROP TABLE IF EXISTS enrollments;
DROP TABLE IF EXISTS timetable;
DROP TABLE IF EXISTS lecturers;
DROP TABLE IF EXISTS courses;
DROP TABLE IF EXISTS students;
SET FOREIGN_KEY_CHECKS = 1;

DROP PROCEDURE IF EXISTS sp_check_timetable_overlap;
DROP PROCEDURE IF EXISTS generate_sessions;
DROP PROCEDURE IF EXISTS mark_attendance;
DROP PROCEDURE IF EXISTS close_session;
DROP PROCEDURE IF EXISTS generate_monthly_report;
