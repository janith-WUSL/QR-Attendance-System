USE attendance_db;

CREATE TABLE students (
    student_id   INT AUTO_INCREMENT PRIMARY KEY,
    reg_no       VARCHAR(20)  NOT NULL UNIQUE,
    name         VARCHAR(150) NOT NULL,
    department   VARCHAR(100),
    email        VARCHAR(150) UNIQUE,
    course_batch VARCHAR(50)
) ENGINE=InnoDB;

CREATE TABLE courses (
    course_id   INT AUTO_INCREMENT PRIMARY KEY,
    course_code VARCHAR(20)  NOT NULL UNIQUE,
    course_name VARCHAR(200) NOT NULL,
    semester    VARCHAR(50)  NOT NULL
) ENGINE=InnoDB;

CREATE TABLE lecturers (
    lecturer_id   INT AUTO_INCREMENT PRIMARY KEY,
    username      VARCHAR(50)  NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name     VARCHAR(150) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE enrollments (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL,
    course_id  INT NOT NULL,
    UNIQUE KEY uq_enroll (student_id, course_id),
    CONSTRAINT fk_enr_student FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_enr_course  FOREIGN KEY (course_id)  REFERENCES courses(course_id)   ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE timetable (
    timetable_id INT AUTO_INCREMENT PRIMARY KEY,
    course_id    INT NOT NULL,
    lecturer_id  INT NOT NULL,
    day_of_week  VARCHAR(10) NOT NULL,
    start_time   TIME NOT NULL,
    end_time     TIME NOT NULL,
    session_type CHAR(1) NOT NULL DEFAULT 'L',
    group_name   VARCHAR(20),
    CONSTRAINT chk_day  CHECK (day_of_week IN ('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')),
    CONSTRAINT chk_time CHECK (end_time > start_time),
    CONSTRAINT chk_type CHECK (session_type IN ('L','P')),
    CONSTRAINT fk_tt_course   FOREIGN KEY (course_id)   REFERENCES courses(course_id)     ON DELETE CASCADE,
    CONSTRAINT fk_tt_lecturer FOREIGN KEY (lecturer_id) REFERENCES lecturers(lecturer_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE lecture_sessions (
    session_id   INT AUTO_INCREMENT PRIMARY KEY,
    timetable_id INT  NOT NULL,
    session_date DATE NOT NULL,
    qr_token     VARCHAR(255) NOT NULL UNIQUE,
    UNIQUE KEY uq_session (timetable_id, session_date),
    CONSTRAINT fk_ls_tt FOREIGN KEY (timetable_id) REFERENCES timetable(timetable_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE attendance_records (
    record_id   INT AUTO_INCREMENT PRIMARY KEY,
    session_id  INT NOT NULL,
    student_id  INT NOT NULL,
    status      VARCHAR(10) NOT NULL DEFAULT 'PRESENT',
    marked_time DATETIME NULL,
    UNIQUE KEY uq_attendance (session_id, student_id),
    CONSTRAINT chk_status CHECK (status IN ('PRESENT','ABSENT','LATE')),
    CONSTRAINT fk_ar_session FOREIGN KEY (session_id) REFERENCES lecture_sessions(session_id) ON DELETE CASCADE,
    CONSTRAINT fk_ar_student FOREIGN KEY (student_id) REFERENCES students(student_id)         ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE monthly_reports (
    report_id          INT AUTO_INCREMENT PRIMARY KEY,
    student_id         INT NOT NULL,
    course_id          INT NOT NULL,
    month_year         VARCHAR(7) NOT NULL,
    attendance_percent DECIMAL(5,2),
    sent_at            DATETIME NULL,
    UNIQUE KEY uq_report (student_id, course_id, month_year),
    CONSTRAINT chk_month   CHECK (month_year REGEXP '^[0-9]{4}-(0[1-9]|1[0-2])$'),
    CONSTRAINT chk_percent CHECK (attendance_percent BETWEEN 0 AND 100),
    CONSTRAINT fk_mr_student FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_mr_course  FOREIGN KEY (course_id)  REFERENCES courses(course_id)   ON DELETE CASCADE
) ENGINE=InnoDB;
