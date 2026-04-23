-- ============================================================
--  Event Ticketing & Entry Database
--  triggers.sql — Trigger Definitions
--  Run AFTER schema.sql
-- ============================================================

USE event_ticketing_db;

DELIMITER $$

-- ------------------------------------------------------------
-- Trigger 1: before_insert_booking
-- Fires BEFORE INSERT on bookings.
-- Validates that enough seats are available in the chosen
-- ticket_category. Raises SQLSTATE '45000' if not, aborting
-- the insert so overselling is impossible at DB level.
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS before_insert_booking$$

CREATE TRIGGER before_insert_booking
BEFORE INSERT ON bookings
FOR EACH ROW
BEGIN
  DECLARE v_available INT;

  SELECT seats_available
    INTO v_available
    FROM ticket_categories
   WHERE category_id = NEW.category_id
     FOR UPDATE;                          -- lock row to prevent race conditions

  IF v_available < NEW.quantity THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Not enough seats available in the selected category.';
  END IF;
END$$

-- ------------------------------------------------------------
-- Trigger 2: after_booking_confirmed
-- Fires AFTER UPDATE on bookings.
-- When status changes to 'confirmed', deducts the booked
-- quantity from ticket_categories.seats_available.
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS after_booking_confirmed$$

CREATE TRIGGER after_booking_confirmed
AFTER UPDATE ON bookings
FOR EACH ROW
BEGIN
  IF NEW.status = 'confirmed' AND OLD.status <> 'confirmed' THEN
    UPDATE ticket_categories
       SET seats_available = seats_available - NEW.quantity
     WHERE category_id = NEW.category_id;
  END IF;
END$$

-- ------------------------------------------------------------
-- Trigger 3: after_booking_cancelled
-- Fires AFTER UPDATE on bookings.
-- When status changes TO 'cancelled' FROM 'confirmed',
-- restores seats back to ticket_categories.seats_available.
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS after_booking_cancelled$$

CREATE TRIGGER after_booking_cancelled
AFTER UPDATE ON bookings
FOR EACH ROW
BEGIN
  IF NEW.status = 'cancelled' AND OLD.status = 'confirmed' THEN
    UPDATE ticket_categories
       SET seats_available = seats_available + NEW.quantity
     WHERE category_id = NEW.category_id;
  END IF;
END$$

-- ------------------------------------------------------------
-- Trigger 4: before_entry_log_insert
-- Fires BEFORE INSERT on entry_logs.
-- Checks that the ticket being scanned:
--   (a) exists and belongs to a confirmed booking
--   (b) has not already been used (is_used = 0)
-- If either check fails, raises an error to abort the scan.
-- On success, marks the ticket as used.
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS before_entry_log_insert$$

CREATE TRIGGER before_entry_log_insert
BEFORE INSERT ON entry_logs
FOR EACH ROW
BEGIN
  DECLARE v_is_used     TINYINT(1);
  DECLARE v_bk_status   VARCHAR(20);

  SELECT t.is_used, b.status
    INTO v_is_used, v_bk_status
    FROM tickets  t
    JOIN bookings b ON t.booking_id = b.booking_id
   WHERE t.ticket_id = NEW.ticket_id;

  IF v_bk_status <> 'confirmed' THEN
    SIGNAL SQLSTATE '45001'
      SET MESSAGE_TEXT = 'Entry denied: booking is not confirmed.';
  END IF;

  IF v_is_used = 1 THEN
    SIGNAL SQLSTATE '45002'
      SET MESSAGE_TEXT = 'Entry denied: ticket has already been used.';
  END IF;

  -- Mark ticket as used atomically with the log insert
  UPDATE tickets
     SET is_used = 1
   WHERE ticket_id = NEW.ticket_id;
END$$

DELIMITER ;