USE attendance_db;

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

INSERT INTO lecturers (username, password_hash, full_name) VALUES
('chathurangani', SHA2('ChangeMe@123', 256), 'Dr. (Ms.) Chathurangani Karunarathna'),
('asanka',        SHA2('ChangeMe@123', 256), 'Dr. Asanka Rajapaksha'),
('upeka',         SHA2('ChangeMe@123', 256), 'Dr. (Ms.) Upeka Samarakoon'),
('upanith',       SHA2('ChangeMe@123', 256), 'Dr. Upanith Liyanaarachchi'),
('ashane',        SHA2('ChangeMe@123', 256), 'Dr. Ashane Fernando'),
('ayanthi',       SHA2('ChangeMe@123', 256), 'Ms. Ayanthi Rathnayake'),
('sajeewani',     SHA2('ChangeMe@123', 256), 'Ms. Sajeewani Fernando'),
('gayan',         SHA2('ChangeMe@123', 256), 'Dr. Gayan Chathuranga');

INSERT INTO enrollments (student_id, course_id)
SELECT s.student_id, c.course_id FROM students s CROSS JOIN courses c;

INSERT INTO timetable (course_id, lecturer_id, day_of_week, start_time, end_time, session_type, group_name)
SELECT c.course_id, l.lecturer_id, v.dname, v.st, v.et, v.stype, v.grp
FROM (
    SELECT 'NANO2172' AS code, 'ayanthi'       AS uname, 'Monday'    AS dname, '08:30:00' AS st, '10:30:00' AS et, 'L' AS stype, NULL AS grp
    UNION ALL SELECT 'NANO2162','ashane',       'Monday',    '10:30:00','12:30:00','P', NULL
    UNION ALL SELECT 'NANO2162','ashane',       'Monday',    '13:30:00','15:30:00','L', NULL
    UNION ALL SELECT 'NANO2122','asanka',       'Tuesday',   '08:30:00','10:30:00','L', NULL
    UNION ALL SELECT 'NANO2132','upeka',        'Tuesday',   '10:30:00','12:30:00','L', NULL
    UNION ALL SELECT 'NANO2142','upanith',      'Tuesday',   '13:30:00','15:30:00','L', NULL
    UNION ALL SELECT 'PDEV2110','gayan',        'Tuesday',   '15:30:00','17:30:00','L', NULL
    UNION ALL SELECT 'ETCH2111','sajeewani',    'Wednesday', '08:30:00','10:30:00','L', NULL
    UNION ALL SELECT 'NANO2112','chathurangani','Wednesday', '10:30:00','12:30:00','L', NULL
    UNION ALL SELECT 'NANO2142','upanith',      'Thursday',  '08:30:00','10:30:00','P', NULL
    UNION ALL SELECT 'NANO2182','ayanthi',      'Thursday',  '10:30:00','12:30:00','L', NULL
    UNION ALL SELECT 'NANO2151','chathurangani','Thursday',  '13:30:00','15:30:00','L', NULL
    UNION ALL SELECT 'NANO2132','upeka',        'Friday',    '10:30:00','12:30:00','P', 'Group 1'
) v
JOIN courses   c ON c.course_code = v.code
JOIN lecturers l ON l.username    = v.uname;
