INSERT INTO actor.org_unit (id, parent_ou, ou_type, shortname, name) VALUES 
    (2, 1, 2, 'SYS1', oils_i18n_gettext(2, 'Example System 1', 'aou', 'name'));
INSERT INTO actor.org_unit (id, parent_ou, ou_type, shortname, name) VALUES 
    (3, 1, 2, 'SYS2', oils_i18n_gettext(3, 'Example System 2', 'aou', 'name'));
INSERT INTO actor.org_unit (id, parent_ou, ou_type, shortname, name) VALUES 
    (10, 1, 2, 'SYS3', oils_i18n_gettext(10, 'Example System 3', 'aou', 'name'));
INSERT INTO actor.org_unit (id, parent_ou, ou_type, shortname, name) VALUES 
    (12, 1, 2, 'SYS4', oils_i18n_gettext(12, 'Example System 4', 'aou', 'name'));
INSERT INTO actor.org_unit (id, parent_ou, ou_type, shortname, name) VALUES 
    (4, 2, 3, 'BR1', oils_i18n_gettext(4, 'Example Branch 1', 'aou', 'name'));
INSERT INTO actor.org_unit (id, parent_ou, ou_type, shortname, name) VALUES 
    (5, 2, 3, 'BR2', oils_i18n_gettext(5, 'Example Branch 2', 'aou', 'name'));
INSERT INTO actor.org_unit (id, parent_ou, ou_type, shortname, name) VALUES 
    (6, 3, 3, 'BR3', oils_i18n_gettext(6, 'Example Branch 3', 'aou', 'name'));
INSERT INTO actor.org_unit (id, parent_ou, ou_type, shortname, name) VALUES 
    (7, 3, 3, 'BR4', oils_i18n_gettext(7, 'Example Branch 4', 'aou', 'name'));
INSERT INTO actor.org_unit (id, parent_ou, ou_type, shortname, name) VALUES 
    (11, 10, 3, 'BR5', oils_i18n_gettext(11, 'Example Branch 5', 'aou', 'name'));
INSERT INTO actor.org_unit (id, parent_ou, ou_type, shortname, name) VALUES 
    (13, 12, 3, 'BR6', oils_i18n_gettext(13, 'Example Branch 6', 'aou', 'name'));
INSERT INTO actor.org_unit (id, parent_ou, ou_type, shortname, name) VALUES 
    (8, 4, 4, 'SL1', oils_i18n_gettext(8, 'Example Sub-library 1', 'aou', 'name'));
INSERT INTO actor.org_unit (id, parent_ou, ou_type, shortname, name) VALUES 
    (9, 6, 5, 'BM1', oils_i18n_gettext(9, 'Example Bookmobile 1', 'aou', 'name'));



-- Address for the Consortium
SELECT evergreen.create_aou_address(1, '250 Georgia Ave SE #103', NULL, 'Atlanta', 'GA', 'US', '30312', NULL);

-- Addresses for System 1
SELECT evergreen.create_aou_address(2, '1721 Waters Ave', NULL, 'Savannah', 'GA', 'US', '31404', NULL);

-- Addresses for System 2
SELECT evergreen.create_aou_address(3, '831 Adams St', NULL, 'Macon', 'GA', 'US', '31201', NULL);

-- Addresses for System 3
SELECT evergreen.create_aou_address(10, '215 N Lumpkin St', NULL, 'Athens', 'GA', 'US', '30601', NULL);

-- Addresses for System 4
SELECT evergreen.create_aou_address(12, '625 Academy St NE', NULL, 'Gainesville', 'GA', 'US', '30501', NULL);

-- Addresses for Branch 1
SELECT evergreen.create_aou_address(4, 'BR1', '250 Georgia Ave SE #103', 'Atlanta', 'GA', 'US', '30312', 'billing mailing');
SELECT evergreen.create_aou_address(4, 'Holds and ILL', '250 Georgia Ave SE #103', 'Atlanta', 'GA', 'US', '30312', 'interlibrary holds');

-- Addresses for Branch 2
SELECT evergreen.create_aou_address(5, 'BR2', '1721 Waters Ave', 'Savannah', 'GA', 'US', '31404', 'mailing');
SELECT evergreen.create_aou_address(5, 'BR2 - Billing', '1721 Waters Ave', 'Savannah', 'GA', 'US', '31404', 'billing');
SELECT evergreen.create_aou_address(5, 'BR2 - Holds and ILL', '1721 Waters Ave', 'Savannah', 'GA', 'US', '31404', 'interlibrary holds');

-- Addresses for Branch 3
SELECT evergreen.create_aou_address(6, 'BR3', '831 Adams St', 'Macon', 'GA', 'US', '31201', NULL);

-- Addresses for Branch 4
SELECT evergreen.create_aou_address(7, 'BR4', '419 7th St', 'Augusta', 'GA', 'US', '30901', 'mailing');
SELECT evergreen.create_aou_address(7, 'BR4 - Billing Dept', '419 7th St', 'Augusta', 'GA', 'US', '30901', 'billing');
SELECT evergreen.create_aou_address(7, 'BR4 - Holds and ILL', '419 7th St', 'Augusta', 'GA', 'US', '30901', 'interlibrary holds');

-- Addresses for Branch 5
SELECT evergreen.create_aou_address(11, 'BR5', '215 N Lumpkin St', 'Athens', 'GA', 'US', '30601', NULL);

-- Addresses for Branch 6
SELECT evergreen.create_aou_address(13, 'BR6', '625 Academy St NE', 'Gainesville', 'GA', 'US', '30501', NULL);

-- Hours for branches
INSERT INTO actor.hours_of_operation (id, dow_0_open, dow_0_close, dow_1_open, dow_1_close,
    dow_2_open, dow_2_close, dow_3_open, dow_3_close, dow_4_open, dow_4_close,
    dow_5_open, dow_5_close, dow_6_open, dow_6_close) VALUES
-- BR1 - closed on weekends (convention is 00:00 - 00:00)
    (4, '08:00', '23:30', '08:00', '23:30', '08:00', '23:30', '08:00', '23:30', '09:00', '23:30', '00:00', '00:00', '00:00', '00:00'),
-- BR2 - accept defaults of 09:00 - 17:00 for some days
    (5, '08:30', '21:30', '09:30', '14:30', '10:00', '21:30', '08:30', '17:00', '09:00', '17:00', '09:00', '17:00', '09:00', '17:00'),
-- BR3 - accept defaults of 09:00 - 17:00 for some days
    (6, '08:00', '23:30', '08:00', '23:30', '08:00', '23:30', '08:00', '23:30', '09:00', '23:30', '13:00', '23:30', '09:00', '23:30'),
-- BR4 - accept defaults of 09:00 - 17:00 for each day
    (7, '09:00', '17:00', '09:00', '17:00', '09:00', '17:00', '09:00', '17:00', '09:00', '17:00', '09:00', '17:00', '09:00', '17:00');

-- Set some information URLs for library branches
INSERT INTO actor.org_unit_setting(org_unit, name, value) VALUES
    (4, 'lib.info_url', '"http://example.com/BR1"'), -- BR1
    (5, 'lib.info_url', '"http://example.com/BR2"'), -- BR2
    (6, 'lib.info_url', '"http://br3.example.com"'), -- BR3
    (7, 'lib.info_url', '"http://br4.example.com/info"'); -- BR4

INSERT INTO actor.org_unit_shipping_hub(org_unit, hub) VALUES (2,4),(3,7),(10,11);
INSERT INTO actor.org_unit_shipping_hub_distance(orig_hub, dest_hub, distance) VALUES (4,4,0),(4,7,25),(4,11,50),
                                                                            (7,7,0),(7,4,25),(7,11,65),
                                                                            (11,7,65),(11,4,50),(11,11,0);


UPDATE actor.org_unit SET email = 'br1@example.com', phone = '(555) 555-0271' WHERE shortname = 'BR1';
UPDATE actor.org_unit SET email = 'br2@example.com', phone = '(555) 555-0272' WHERE shortname = 'BR2';
UPDATE actor.org_unit SET email = 'br3@example.com', phone = '(555) 555-0273' WHERE shortname = 'BR3';
UPDATE actor.org_unit SET email = 'br4@example.com', phone = '(555) 555-0274' WHERE shortname = 'BR4';
UPDATE actor.org_unit SET email = 'br5@example.com', phone = '(555) 555-0275' WHERE shortname = 'BR5';
UPDATE actor.org_unit SET email = 'br6@example.com', phone = '(555) 555-0276' WHERE shortname = 'BR6';
