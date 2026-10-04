# QR-Attendance-System
QR-Based University Attendance Management System
# QR-Based University Attendance Management System

A desktop application that records university lecture attendance using QR codes, calculates attendance percentages automatically, monitors the 80% minimum attendance requirement, and sends monthly reports to students by email.

**Department of Nano Science, Faculty of Technology, Wayamba University of Sri Lanka**
Course: NANO2142 (Introduction to Software Development) | Group 03

## Features

- Secure login for lecturers and administrators
- Student, lecturer, and course management
- Lecture session management
- Unique QR code for every lecture session
- QR-based attendance recording with duplicate prevention
- Automatic attendance percentage calculation
- 80% attendance monitoring
- Attendance reports (student, course, daily, monthly)
- Monthly email reports to students

## Tech Stack

- Language: C++
- GUI: Qt 6 (Qt Widgets)
- Database: MySQL 8.0+
- IDE: Qt Creator
- Version control: Git / GitHub

## Requirements

- Qt 6 with the Qt SQL module (Qt Creator)
- MySQL Server 8.0 or later
- MySQL Workbench (recommended)
- `libmysql.dll` from your MySQL installation (Windows)

## Setup

### 1. Clone the repository

```bash
git clone <repository-url>
cd AttendanceSystem
```

### 2. Create the database

Open MySQL Workbench, connect to your MySQL server, and run the SQL files in the `database/` folder **in this order**. Open each file with `File > Open SQL Script...` and click the lightning-bolt (Execute all) button. Do not select only a part of the script.

| Order | File | Purpose |
|---|---|---|
| 1 | `01_database_reset.sql` | Creates the database and removes old objects |
| 2 | `02_tables.sql` | Creates the tables |
| 3 | `03_indexes.sql` | Creates the indexes |
| 4 | `04_procedures_triggers.sql` | Creates stored procedures and triggers |
| 5 | `05_views.sql` | Creates the views |
| 6 | `06_seed_data.sql` | Inserts students, courses, lecturers, timetable |
| 7 | `07_demo_data.sql` | Optional demo attendance data (delete for production) |

> Warning: running `01_database_reset.sql` again deletes all existing data.

### 3. Create the application database user

Run this in MySQL Workbench (change the password):

```sql
CREATE USER 'attendance_app'@'localhost' IDENTIFIED BY 'YOUR_PASSWORD';
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON attendance_db.* TO 'attendance_app'@'localhost';
FLUSH PRIVILEGES;
```

### 4. Configure the connection

Set the database host, port, name, username, and password in the application's database settings (`DatabaseManager`). Never commit real passwords to GitHub.

### 5. Copy `libmysql.dll` (Windows)

1. Go to your MySQL installation folder, for example:
   `C:\Program Files\MySQL\MySQL Server 8.0\lib\`
2. Copy `libmysql.dll`.
3. Paste it next to the application's `.exe` file in your build folder.

The DLL must match your Qt kit (64-bit kit needs the 64-bit DLL).

### 6. Open and run in Qt Creator

1. Open Qt Creator and choose `File > Open File or Project...`.
2. Select `CMakeLists.txt` from this repository.
3. Select a Desktop Qt 6 kit (MinGW 64-bit or MSVC 64-bit) and click **Configure Project**.
4. Press `Ctrl+R` to build and run.
5. Check the **Application Output** panel. If the `QMYSQL` driver is listed and the window opens, the database connection works.

## Troubleshooting

| Problem | Solution |
|---|---|
| `Driver not loaded` | `libmysql.dll` is missing or does not match the kit (32/64-bit) |
| `Access denied for user` | Check the username/password and the `GRANT` statement |
| `Can't connect to MySQL server` | Start the MySQL service (`MySQL80` in Windows Services) |
| `Unknown database` | Run the SQL files in `database/` in the correct order |

## Project Structure

```
AttendanceSystem/
├── database/        SQL scripts (01 - 07)
├── src/             C++ source files
├── CMakeLists.txt
├── .gitignore
└── README.md
```

## Team (Group 03)

| Student ID | Name | Role |
|---|---|---|
| 249111 | Kalubovila K.A.J.H | Team Leader & System Integrator |
| 249028 | Bandara L.R.P.H | UI/UX Developer |
| 249177 | Rathnayaka K.G | Database Developer |
| 249208 | Subanya I.L.P | OOP & Core Logic Developer |
| 249044 | Deshan K.W.A.D | QR & Email Integration Developer |