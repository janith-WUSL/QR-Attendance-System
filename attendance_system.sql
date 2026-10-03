-- =====================================================================
-- QR Attendance System - PostgreSQL schema + seed data
-- Based on: ER diagram, student list (Reg No), Level 2 Sem I timetable
-- =====================================================================

DROP TABLE IF EXISTS attendance_records CASCADE;
DROP TABLE IF EXISTS lecture_sessions   CASCADE;
DROP TABLE IF EXISTS monthly_reports    CASCADE;
DROP TABLE IF EXISTS enrollments        CASCADE;
DROP TABLE IF EXISTS timetable          CASCADE;
DROP TABLE IF EXISTS lecturers          CASCADE;
DROP TABLE IF EXISTS courses            CASCADE;
DROP TABLE IF EXISTS students           CASCADE;

-- ---------------------------------------------------------------------
-- 1. STUDENTS
-- ---------------------------------------------------------------------
CREATE TABLE students (
    student_id   SERIAL PRIMARY KEY,
    reg_no       VARCHAR(20)  NOT NULL UNIQUE,      -- e.g. 249002 (from student list)
    name         VARCHAR(150) NOT NULL,
    department   VARCHAR(100),
    email        VARCHAR(150) UNIQUE,
    course_batch VARCHAR(50)
);

-- ---------------------------------------------------------------------
-- 2. COURSES
-- ---------------------------------------------------------------------
CREATE TABLE courses (
    course_id   SERIAL PRIMARY KEY,
    course_code VARCHAR(20)  NOT NULL UNIQUE,
    course_name VARCHAR(200) NOT NULL,
    semester    VARCHAR(50)  NOT NULL
);

-- ---------------------------------------------------------------------
-- 3. LECTURERS
-- ---------------------------------------------------------------------
CREATE TABLE lecturers (
    lecturer_id   SERIAL PRIMARY KEY,
    username      VARCHAR(50)  NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name     VARCHAR(150) NOT NULL
);

-- ---------------------------------------------------------------------
-- 4. ENROLLMENTS  (students <-> courses, many-to-many)
-- ---------------------------------------------------------------------
CREATE TABLE enrollments (
    id         SERIAL PRIMARY KEY,
    student_id INT NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
    course_id  INT NOT NULL REFERENCES courses(course_id)   ON DELETE CASCADE,
    UNIQUE (student_id, course_id)
);

-- ---------------------------------------------------------------------
-- 5. TIMETABLE
-- ---------------------------------------------------------------------
CREATE TABLE timetable (
    timetable_id SERIAL PRIMARY KEY,
    course_id    INT NOT NULL REFERENCES courses(course_id)     ON DELETE CASCADE,
    lecturer_id  INT NOT NULL REFERENCES lecturers(lecturer_id) ON DELETE RESTRICT,
    day_of_week  VARCHAR(10) NOT NULL
                 CHECK (day_of_week IN ('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')),
    start_time   TIME NOT NULL,
    end_time     TIME NOT NULL,
    session_type CHAR(1) NOT NULL DEFAULT 'L' CHECK (session_type IN ('L','P')),  -- L=Lecture, P=Practical
    group_name   VARCHAR(20),                                                     -- e.g. 'Group 1'
    CHECK (end_time > start_time)
);

-- ---------------------------------------------------------------------
-- 6. LECTURE_SESSIONS  (one row per actual lecture date, holds QR token)
-- ---------------------------------------------------------------------
CREATE TABLE lecture_sessions (
    session_id   SERIAL PRIMARY KEY,
    timetable_id INT  NOT NULL REFERENCES timetable(timetable_id) ON DELETE CASCADE,
    session_date DATE NOT NULL,
    qr_token     VARCHAR(255) NOT NULL UNIQUE,
    UNIQUE (timetable_id, session_date)
);

-- ---------------------------------------------------------------------
-- 7. ATTENDANCE_RECORDS
-- ---------------------------------------------------------------------
CREATE TABLE attendance_records (
    record_id   SERIAL PRIMARY KEY,
    session_id  INT NOT NULL REFERENCES lecture_sessions(session_id) ON DELETE CASCADE,
    student_id  INT NOT NULL REFERENCES students(student_id)         ON DELETE CASCADE,
    status      VARCHAR(10) NOT NULL DEFAULT 'PRESENT'
                CHECK (status IN ('PRESENT','ABSENT','LATE')),
    marked_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (session_id, student_id)          -- one mark per student per session
);

-- ---------------------------------------------------------------------
-- 8. MONTHLY_REPORTS
-- ---------------------------------------------------------------------
CREATE TABLE monthly_reports (
    report_id          SERIAL PRIMARY KEY,
    student_id         INT NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
    course_id          INT NOT NULL REFERENCES courses(course_id)   ON DELETE CASCADE,
    month_year         VARCHAR(7) NOT NULL,                 -- format 'YYYY-MM'
    attendance_percent NUMERIC(5,2) CHECK (attendance_percent BETWEEN 0 AND 100),
    sent_at            TIMESTAMP,
    UNIQUE (student_id, course_id, month_year)
);

-- ---------------------------------------------------------------------
-- INDEXES
-- ---------------------------------------------------------------------
CREATE INDEX idx_timetable_course   ON timetable(course_id);
CREATE INDEX idx_timetable_lecturer ON timetable(lecturer_id);
CREATE INDEX idx_sessions_date      ON lecture_sessions(session_date);
CREATE INDEX idx_attendance_student ON attendance_records(student_id);
CREATE INDEX idx_reports_student    ON monthly_reports(student_id);

-- =====================================================================
-- SEED DATA
-- =====================================================================

-- Students (from the uploaded list)
INSERT INTO students (reg_no, name, department, course_batch) VALUES
('249002', 'ABAYATHISSA P.T.S.',   'Nano Science Technology', 'N3'),
('249003', 'ABESINGHE K.H.',       'Nano Science Technology', 'N3'),
('249027', 'BANDARA K.P.D.',       'Nano Science Technology', 'N3'),
('249028', 'BANDARA L.R.P.H.',     'Nano Science Technology', 'N3'),
('249029', 'BANDARA R.D.R.L.',     'Nano Science Technology', 'N3'),
('249030', 'BANDARA S.R.T.K.D.M.', 'Nano Science Technology', 'N3'),
('249032', 'BASNAYAKA B.M.G.P.',   'Nano Science Technology', 'N3'),
('249034', 'CHAMARA E.P.U.',       'Nano Science Technology', 'N3'),
('249036', 'CHAMOD H.A.V.',        'Nano Science Technology', 'N3'),
('249037', 'CHANDEEPA R.A.S.',     'Nano Science Technology', 'N3');

-- Courses (Level 2 Semester I)
INSERT INTO courses (course_code, course_name, semester) VALUES
('NANO2112', 'Mathematics for Nano Science Technology I',  'Level 2 Semester I'),
('NANO2122', 'Fundamentals of Nano-Electronics',           'Level 2 Semester I'),
('NANO2132', 'Digital Electronics',                        'Level 2 Semester I'),
('NANO2142', 'Introduction to Software Development',       'Level 2 Semester I'),
('NANO2151', 'Principles of Material Science Engineering', 'Level 2 Semester I'),
('NANO2162', 'Engineering Design & Drawings',              'Level 2 Semester I'),
('NANO2172', 'Physical Chemistry for Nanotechnology',      'Level 2 Semester I'),
('NANO2182', 'Management for Technology',                  'Level 2 Semester I'),
('ETCH2111', 'English Language & Communication Skills II', 'Level 2 Semester I'),
('PDEV2110', 'Career Development II',                      'Level 2 Semester I');

-- Lecturers
-- NOTE: password_hash values are PLACEHOLDERS. Replace with real bcrypt hashes
-- generated by your application (never store plain-text passwords).
INSERT INTO lecturers (username, password_hash, full_name) VALUES
('chathurangani', '$2b$12$REPLACE_WITH_REAL_BCRYPT_HASH', 'Dr. (Ms.) Chathurangani Karunarathna'),
('asanka',        '$2b$12$REPLACE_WITH_REAL_BCRYPT_HASH', 'Dr. Asanka Rajapaksha'),
('upeka',         '$2b$12$REPLACE_WITH_REAL_BCRYPT_HASH', 'Dr. (Ms.) Upeka Samarakoon'),
('upanith',       '$2b$12$REPLACE_WITH_REAL_BCRYPT_HASH', 'Dr. Upanith Liyanaarachchi'),
('ashane',        '$2b$12$REPLACE_WITH_REAL_BCRYPT_HASH', 'Dr. Ashane Fernando'),
('ayanthi',       '$2b$12$REPLACE_WITH_REAL_BCRYPT_HASH', 'Ms. Ayanthi Rathnayake'),
('sajeewani',     '$2b$12$REPLACE_WITH_REAL_BCRYPT_HASH', 'Ms. Sajeewani Fernando'),
('gayan',         '$2b$12$REPLACE_WITH_REAL_BCRYPT_HASH', 'Dr. Gayan Chathuranga');

-- Enroll every student in every course
INSERT INTO enrollments (student_id, course_id)
SELECT s.student_id, c.course_id
FROM students s CROSS JOIN courses c;

-- Timetable (Lecture Hall N3-01)
-- Helper: resolve ids via course_code / username
INSERT INTO timetable (course_id, lecturer_id, day_of_week, start_time, end_time, session_type, group_name)
SELECT c.course_id, l.lecturer_id, v.day, v.st::time, v.et::time, v.stype, v.grp
FROM (VALUES
  -- Monday
  ('NANO2172','ayanthi',      'Monday',    '08:30','10:30','L', NULL),
  ('NANO2162','ashane',       'Monday',    '10:30','12:30','P', NULL),
  ('NANO2162','ashane',       'Monday',    '13:30','15:30','L', NULL),
  -- Tuesday
  ('NANO2122','asanka',       'Tuesday',   '08:30','10:30','L', NULL),
  ('NANO2132','upeka',        'Tuesday',   '10:30','12:30','L', NULL),
  ('NANO2142','upanith',      'Tuesday',   '13:30','15:30','L', NULL),
  ('PDEV2110','gayan',        'Tuesday',   '15:30','17:30','L', NULL),
  -- Wednesday
  ('ETCH2111','sajeewani',    'Wednesday', '08:30','10:30','L', NULL),
  ('NANO2112','chathurangani','Wednesday', '10:30','12:30','L', NULL),
  -- Thursday
  ('NANO2142','upanith',      'Thursday',  '08:30','10:30','P', NULL),
  ('NANO2182','ayanthi',      'Thursday',  '10:30','12:30','L', NULL),
  ('NANO2151','chathurangani','Thursday',  '13:30','15:30','L', NULL),
  -- Friday
  ('NANO2132','upeka',        'Friday',    '10:30','12:30','P', 'Group 1')
) AS v(code, uname, day, st, et, stype, grp)
JOIN courses   c ON c.course_code = v.code
JOIN lecturers l ON l.username    = v.uname;

-- =====================================================================
-- USEFUL QUERIES
-- =====================================================================

-- A) Full weekly timetable
-- SELECT t.day_of_week, t.start_time, t.end_time, c.course_code, c.course_name,
--        t.session_type, l.full_name
-- FROM timetable t
-- JOIN courses c   ON c.course_id   = t.course_id
-- JOIN lecturers l ON l.lecturer_id = t.lecturer_id
-- ORDER BY array_position(ARRAY['Monday','Tuesday','Wednesday','Thursday','Friday'], t.day_of_week::text),
--          t.start_time;

-- B) Attendance percentage per student per course for a given month ('2026-10')
-- SELECT s.reg_no, s.name, c.course_code,
--        ROUND(100.0 * COUNT(*) FILTER (WHERE a.status IN ('PRESENT','LATE')) / COUNT(*), 2) AS attendance_percent
-- FROM attendance_records a
-- JOIN lecture_sessions ls ON ls.session_id   = a.session_id
-- JOIN timetable t         ON t.timetable_id  = ls.timetable_id
-- JOIN courses c           ON c.course_id     = t.course_id
-- JOIN students s          ON s.student_id    = a.student_id
-- WHERE TO_CHAR(ls.session_date, 'YYYY-MM') = '2026-10'
-- GROUP BY s.reg_no, s.name, c.course_code;

-- C) Generate monthly_reports from attendance (upsert)
-- INSERT INTO monthly_reports (student_id, course_id, month_year, attendance_percent)
-- SELECT a.student_id, t.course_id, TO_CHAR(ls.session_date,'YYYY-MM'),
--        ROUND(100.0 * COUNT(*) FILTER (WHERE a.status IN ('PRESENT','LATE')) / COUNT(*), 2)
-- FROM attendance_records a
-- JOIN lecture_sessions ls ON ls.session_id  = a.session_id
-- JOIN timetable t         ON t.timetable_id = ls.timetable_id
-- GROUP BY a.student_id, t.course_id, TO_CHAR(ls.session_date,'YYYY-MM')
-- ON CONFLICT (student_id, course_id, month_year)
-- DO UPDATE SET attendance_percent = EXCLUDED.attendance_percent;
