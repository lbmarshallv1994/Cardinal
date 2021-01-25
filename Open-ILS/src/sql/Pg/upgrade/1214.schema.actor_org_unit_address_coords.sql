BEGIN;

INSERT INTO config.upgrade_log (version) VALUES ('1214'); 

ALTER TABLE actor.org_address
ADD COLUMN latitude NUMERIC,
ADD COLUMN longitude NUMERIC;


COMMIT;