BEGIN;

INSERT INTO config.upgrade_log (version) VALUES ('1212'); 

ALTER TABLE actor.org_unit
ADD COLUMN shipping_hub_ou BIGINT REFERENCES actor.org_unit(id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION actor.list_org_unit_ancestor_shipping_hub(VARIADIC orgs NUMERIC[]) RETURNS TABLE(org_unit INT,hub INT)
  AS
$func$
DECLARE
    rec record;
    cur_org INT;
    next_hub INT;
    org_id INT;
BEGIN
    FOREACH org_id IN ARRAY orgs LOOP
    cur_org := org_id;
    org_unit := cur_org;
    LOOP
        SELECT INTO next_hub actor.org_unit.shipping_hub_ou FROM actor.org_unit WHERE actor.org_unit.id = cur_org;
        IF FOUND AND next_hub IS NOT NULL THEN
            hub := next_hub;
            return next;
            EXIT;
        END IF;
        SELECT INTO cur_org parent_ou FROM actor.org_unit WHERE actor.org_unit.id = cur_org;
        EXIT WHEN cur_org IS NULL;
    END LOOP;
    END LOOP;
    RETURN;
END;
$func$ LANGUAGE PLPGSQL;

COMMIT;