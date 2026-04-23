-- ============================================================
--  Event Ticketing & Entry Database
--  views.sql — View Definitions
--  Run AFTER schema.sql
-- ============================================================

USE event_ticketing_db;

-- ------------------------------------------------------------
-- View 1: event_booking_summary
-- Human-readable sales report: attendee name, event, venue,
-- ticket category, quantity, and total amount paid.
-- ------------------------------------------------------------
DROP VIEW IF EXISTS event_booking_summary;

CREATE VIEW event_booking_summary AS
SELECT
  b.booking_id,
  u.name                        AS attendee_name,
  u.email                       AS attendee_email,
  e.title                       AS event_title,
  e.event_date,
  v.venue_name,
  v.city,
  tc.category_name              AS ticket_category,
  b.quantity,
  b.total_amount,
  b.status                      AS booking_status,
  p.method                      AS payment_method,
  p.status                      AS payment_status,
  b.booked_at
FROM bookings b
JOIN users             u  ON b.user_id     = u.user_id
JOIN events            e  ON b.event_id    = e.event_id
JOIN venues            v  ON e.venue_id    = v.venue_id
JOIN ticket_categories tc ON b.category_id = tc.category_id
LEFT JOIN payments     p  ON b.booking_id  = p.booking_id;

-- ------------------------------------------------------------
-- View 2: event_capacity_status
-- Shows seats sold vs remaining per event and category.
-- ------------------------------------------------------------
DROP VIEW IF EXISTS event_capacity_status;

CREATE VIEW event_capacity_status AS
SELECT
  e.event_id,
  e.title                                           AS event_title,
  e.event_date,
  tc.category_id,
  tc.category_name,
  tc.price,
  tc.seats_available,
  COALESCE(SUM(CASE WHEN b.status = 'confirmed' THEN b.quantity ELSE 0 END), 0)
                                                    AS seats_booked,
  tc.seats_available - COALESCE(SUM(CASE WHEN b.status = 'confirmed' THEN b.quantity ELSE 0 END), 0)
                                                    AS seats_remaining
FROM events            e
JOIN ticket_categories tc ON e.event_id    = tc.event_id
LEFT JOIN bookings     b  ON tc.category_id = b.category_id
GROUP BY e.event_id, e.title, e.event_date,
         tc.category_id, tc.category_name, tc.price, tc.seats_available;

-- ------------------------------------------------------------
-- View 3: attendance_report
-- Gate-level attendance: who entered, which ticket, which gate,
-- and when — for each event.
-- ------------------------------------------------------------
DROP VIEW IF EXISTS attendance_report;

CREATE VIEW attendance_report AS
SELECT
  e.event_id,
  e.title                       AS event_title,
  e.event_date,
  v.venue_name,
  u.name                        AS attendee_name,
  t.qr_code,
  tc.category_name              AS ticket_category,
  el.gate,
  el.scanned_at,
  su.name                       AS scanned_by
FROM entry_logs       el
JOIN tickets          t   ON el.ticket_id   = t.ticket_id
JOIN bookings         b   ON t.booking_id   = b.booking_id
JOIN users            u   ON b.user_id      = u.user_id
JOIN events           e   ON b.event_id     = e.event_id
JOIN venues           v   ON e.venue_id     = v.venue_id
JOIN ticket_categories tc ON b.category_id  = tc.category_id
LEFT JOIN users       su  ON el.scanned_by  = su.user_id;