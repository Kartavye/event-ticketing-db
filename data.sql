-- ============================================================
--  Event Ticketing & Entry Database
--  data.sql — Seed / Sample Data
--  Run AFTER schema.sql
-- ============================================================

USE event_ticketing_db;

-- ------------------------------------------------------------
-- USERS
-- Passwords shown as plain text for readability.
-- In production replace with bcrypt hashes.
-- ------------------------------------------------------------
INSERT INTO users (name, email, password, phone, role) VALUES
  ('Alice Sharma',   'alice@example.com',     'hashed_pw_1', '9876543210', 'attendee'),
  ('Bob Mehta',      'bob@example.com',        'hashed_pw_2', '9123456780', 'attendee'),
  ('Carol Singh',    'carol@example.com',      'hashed_pw_3', '9001122334', 'attendee'),
  ('David Nair',     'david@example.com',      'hashed_pw_4', '9988776655', 'organiser'),
  ('Eve Thomas',     'eve@example.com',        'hashed_pw_5', '9112233445', 'organiser'),
  ('Frank Admin',    'admin@example.com',      'hashed_pw_6', '9000000001', 'admin'),
  ('Gate Staff 1',   'gate1@example.com',      'hashed_pw_7', '9000000002', 'admin');

-- ------------------------------------------------------------
-- VENUES
-- ------------------------------------------------------------
INSERT INTO venues (venue_name, location, city, capacity) VALUES
  ('Grand Arena',       '12 Exhibition Road',        'Mumbai',    5000),
  ('Tech Hub Auditorium','45 Silicon Valley Street', 'Bangalore', 1200),
  ('City Convention Centre', '7 Park Avenue',        'Delhi',     3000);

-- ------------------------------------------------------------
-- EVENTS
-- organiser_id references users(user_id): David=4, Eve=5
-- ------------------------------------------------------------
INSERT INTO events (organiser_id, venue_id, title, description, event_date, start_time, end_time, total_seats, status) VALUES
  (4, 2, 'Tech Fest 2025',
   'Annual technology conference covering AI, cloud computing, and open-source.',
   '2025-11-15', '09:00:00', '18:00:00', 200, 'upcoming'),
  (5, 1, 'Music Mania Live',
   'A spectacular live music night featuring indie and fusion bands.',
   '2025-12-20', '18:00:00', '23:00:00', 4000, 'upcoming'),
  (4, 3, 'Startup Summit 2025',
   'Pitch competitions, keynotes, and networking for entrepreneurs.',
   '2025-10-05', '10:00:00', '17:00:00', 800, 'completed');

-- ------------------------------------------------------------
-- TICKET CATEGORIES
-- ------------------------------------------------------------
-- Tech Fest 2025 (event_id = 1)
INSERT INTO ticket_categories (event_id, category_name, price, seats_available) VALUES
  (1, 'VIP',        1500.00,  20),
  (1, 'General',     600.00, 130),
  (1, 'Early Bird',  400.00,  50);

-- Music Mania Live (event_id = 2)
INSERT INTO ticket_categories (event_id, category_name, price, seats_available) VALUES
  (2, 'Platinum',   3000.00,  200),
  (2, 'Gold',       1500.00, 1500),
  (2, 'Silver',      800.00, 2300);

-- Startup Summit 2025 (event_id = 3)
INSERT INTO ticket_categories (event_id, category_name, price, seats_available) VALUES
  (3, 'Delegate',  2500.00, 0),
  (3, 'Student',    500.00, 0);

-- ------------------------------------------------------------
-- BOOKINGS
-- Alice books 2 General tickets for Tech Fest (confirmed)
-- Bob books 1 VIP ticket for Tech Fest (confirmed)
-- Carol books 3 Silver tickets for Music Mania (pending)
-- ------------------------------------------------------------
INSERT INTO bookings (user_id, event_id, category_id, quantity, total_amount, status) VALUES
  (1, 1, 2, 2, 1200.00, 'confirmed'),  -- Alice: 2x General @ 600
  (2, 1, 1, 1, 1500.00, 'confirmed'),  -- Bob: 1x VIP @ 1500
  (3, 2, 6, 3, 2400.00, 'pending');    -- Carol: 3x Silver @ 800

-- ------------------------------------------------------------
-- PAYMENTS
-- ------------------------------------------------------------
INSERT INTO payments (booking_id, amount, method, status, paid_at) VALUES
  (1, 1200.00, 'upi',  'success', '2025-09-10 11:30:00'),
  (2, 1500.00, 'card', 'success', '2025-09-11 14:05:00'),
  (3,  2400.00, 'card', 'pending', NULL);

-- ------------------------------------------------------------
-- TICKETS  (issued only for confirmed bookings)
-- Alice: 2 tickets, Bob: 1 ticket
-- QR codes would be UUID/HMAC in production
-- ------------------------------------------------------------
INSERT INTO tickets (booking_id, qr_code, is_used) VALUES
  (1, 'QR-TF2025-001-A', 0),
  (1, 'QR-TF2025-001-B', 0),
  (2, 'QR-TF2025-002-A', 1);   -- Bob already entered

-- ------------------------------------------------------------
-- ENTRY_LOGS  (Bob scanned in at Gate A)
-- scanned_by = 7 (Gate Staff 1)
-- ------------------------------------------------------------
INSERT INTO entry_logs (ticket_id, scanned_at, gate, scanned_by) VALUES
  (3, '2025-11-15 09:22:00', 'Gate A', 7);
  ..