-- ============================================================
--  Event Ticketing & Entry Database
--  queries.sql — Reference & Reporting Queries
--  Run AFTER schema.sql + data.sql + views.sql
-- ============================================================

USE event_ticketing_db;

-- ============================================================
-- SECTION A: EVENT & VENUE QUERIES
-- ============================================================

-- A1. All upcoming events with venue details
SELECT
  e.event_id,
  e.title,
  e.event_date,
  e.start_time,
  e.end_time,
  e.total_seats,
  v.venue_name,
  v.city,
  u.name AS organiser
FROM events  e
JOIN venues  v ON e.venue_id     = v.venue_id
JOIN users   u ON e.organiser_id = u.user_id
WHERE e.event_date >= CURDATE()
  AND e.status = 'upcoming'
ORDER BY e.event_date, e.start_time;

-- A2. Events happening in a specific city
SELECT e.title, e.event_date, v.venue_name
FROM events e
JOIN venues v ON e.venue_id = v.venue_id
WHERE v.city = 'Mumbai'
  AND e.event_date >= CURDATE()
ORDER BY e.event_date;

-- A3. Seat availability per category for a specific event
SELECT
  tc.category_name,
  tc.price,
  tc.seats_available,
  COALESCE(SUM(CASE WHEN b.status = 'confirmed' THEN b.quantity ELSE 0 END), 0) AS booked,
  tc.seats_available AS remaining
FROM ticket_categories tc
LEFT JOIN bookings b ON tc.category_id = b.category_id
WHERE tc.event_id = 1
GROUP BY tc.category_id, tc.category_name, tc.price, tc.seats_available;


-- ============================================================
-- SECTION B: BOOKING QUERIES
-- ============================================================

-- B1. All bookings with attendee and event info
SELECT * FROM event_booking_summary ORDER BY booked_at DESC;

-- B2. All confirmed bookings for a specific event
SELECT
  b.booking_id,
  u.name         AS attendee,
  u.email,
  tc.category_name,
  b.quantity,
  b.total_amount,
  b.booked_at
FROM bookings          b
JOIN users             u  ON b.user_id     = u.user_id
JOIN ticket_categories tc ON b.category_id = tc.category_id
WHERE b.event_id = 1
  AND b.status   = 'confirmed'
ORDER BY b.booked_at;

-- B3. Bookings made today
SELECT
  b.booking_id,
  u.name    AS attendee,
  e.title   AS event_title,
  b.total_amount,
  b.status
FROM bookings b
JOIN users  u ON b.user_id  = u.user_id
JOIN events e ON b.event_id = e.event_id
WHERE DATE(b.booked_at) = CURDATE();

-- B4. Count bookings by status per event
SELECT
  e.title,
  b.status,
  COUNT(b.booking_id)  AS booking_count,
  SUM(b.quantity)      AS total_tickets
FROM bookings b
JOIN events   e ON b.event_id = e.event_id
GROUP BY e.event_id, e.title, b.status
ORDER BY e.title, b.status;

-- B5. All bookings for a specific user  (use stored procedure in production)
CALL getUserBookings(1);


-- ============================================================
-- SECTION C: PAYMENT & REVENUE QUERIES
-- ============================================================

-- C1. Revenue per event (confirmed + successful payments only)
SELECT
  e.title          AS event_title,
  e.event_date,
  COUNT(p.payment_id)   AS successful_payments,
  SUM(p.amount)         AS total_revenue
FROM payments p
JOIN bookings b ON p.booking_id = b.booking_id
JOIN events   e ON b.event_id   = e.event_id
WHERE p.status = 'success'
GROUP BY e.event_id, e.title, e.event_date
ORDER BY total_revenue DESC;

-- C2. Revenue breakdown by category
CALL getRevenueSummary();

-- C3. Pending payments (follow-up required)
SELECT
  p.payment_id,
  u.name          AS attendee,
  u.email,
  e.title         AS event_title,
  p.amount,
  p.method,
  b.booked_at
FROM payments p
JOIN bookings b ON p.booking_id = b.booking_id
JOIN users    u ON b.user_id    = u.user_id
JOIN events   e ON b.event_id   = e.event_id
WHERE p.status = 'pending'
ORDER BY b.booked_at;

-- C4. Refunded payments
SELECT
  p.payment_id,
  u.name    AS attendee,
  e.title   AS event_title,
  p.amount  AS refunded_amount,
  p.paid_at AS original_payment
FROM payments p
JOIN bookings b ON p.booking_id = b.booking_id
JOIN users    u ON b.user_id    = u.user_id
JOIN events   e ON b.event_id   = e.event_id
WHERE p.status = 'refunded';


-- ============================================================
-- SECTION D: TICKET QUERIES
-- ============================================================

-- D1. All tickets for a booking
SELECT t.ticket_id, t.qr_code, t.is_used, t.issued_at
FROM tickets t
WHERE t.booking_id = 1;

-- D2. Validate a QR code at the gate (quick lookup)
SELECT
  t.ticket_id,
  t.is_used,
  b.status   AS booking_status,
  u.name     AS attendee_name,
  e.title    AS event_title,
  tc.category_name
FROM tickets           t
JOIN bookings          b  ON t.booking_id  = b.booking_id
JOIN users             u  ON b.user_id     = u.user_id
JOIN events            e  ON b.event_id    = e.event_id
JOIN ticket_categories tc ON b.category_id = tc.category_id
WHERE t.qr_code = 'QR-TF2025-002-A';

-- D3. All unused tickets for an upcoming event
SELECT
  t.ticket_id,
  t.qr_code,
  u.name      AS attendee,
  tc.category_name
FROM tickets           t
JOIN bookings          b  ON t.booking_id  = b.booking_id
JOIN users             u  ON b.user_id     = u.user_id
JOIN ticket_categories tc ON b.category_id = tc.category_id
WHERE b.event_id = 1
  AND t.is_used  = 0
  AND b.status   = 'confirmed';


-- ============================================================
-- SECTION E: ATTENDANCE & ENTRY QUERIES
-- ============================================================

-- E1. Full attendance report for an event
SELECT * FROM attendance_report WHERE event_id = 1;

-- E2. Attendance count per event
CALL getEventAttendance(1);

-- E3. Real-time entry count (how many have scanned in so far)
SELECT
  e.title         AS event_title,
  COUNT(el.log_id) AS attendees_entered
FROM entry_logs   el
JOIN tickets       t  ON el.ticket_id = t.ticket_id
JOIN bookings      b  ON t.booking_id = b.booking_id
JOIN events        e  ON b.event_id   = e.event_id
WHERE e.event_id = 1
GROUP BY e.title;

-- E4. Entry logs per gate (gate traffic analysis)
SELECT
  el.gate,
  COUNT(el.log_id)  AS scans,
  MIN(el.scanned_at) AS first_scan,
  MAX(el.scanned_at) AS last_scan
FROM entry_logs el
JOIN tickets    t  ON el.ticket_id = t.ticket_id
JOIN bookings   b  ON t.booking_id = b.booking_id
WHERE b.event_id = 1
GROUP BY el.gate
ORDER BY scans DESC;

-- E5. Scan a ticket at the gate using the stored procedure
CALL validateAndScanTicket('QR-TF2025-001-A', 'Gate B', 7);


-- ============================================================
-- SECTION F: ADMIN / DASHBOARD QUERIES
-- ============================================================

-- F1. Event capacity overview (uses view)
SELECT * FROM event_capacity_status ORDER BY event_date, category_name;

-- F2. Top events by revenue
SELECT
  e.title,
  e.event_date,
  SUM(p.amount) AS revenue
FROM payments p
JOIN bookings b ON p.booking_id = b.booking_id
JOIN events   e ON b.event_id   = e.event_id
WHERE p.status = 'success'
GROUP BY e.event_id, e.title, e.event_date
ORDER BY revenue DESC
LIMIT 10;

-- F3. Organisers and their event count
SELECT
  u.user_id,
  u.name      AS organiser,
  u.email,
  COUNT(e.event_id) AS events_created
FROM users  u
LEFT JOIN events e ON u.user_id = e.organiser_id
WHERE u.role = 'organiser'
GROUP BY u.user_id, u.name, u.email
ORDER BY events_created DESC;

-- F4. Users who have never booked
SELECT u.user_id, u.name, u.email, u.role
FROM users u
LEFT JOIN bookings b ON u.user_id = b.user_id
WHERE b.booking_id IS NULL
  AND u.role = 'attendee';

-- F5. Events with no bookings yet
SELECT e.event_id, e.title, e.event_date, v.venue_name
FROM events  e
JOIN venues  v ON e.venue_id = v.venue_id
LEFT JOIN bookings b ON e.event_id = b.event_id
WHERE b.booking_id IS NULL
  AND e.status = 'upcoming';