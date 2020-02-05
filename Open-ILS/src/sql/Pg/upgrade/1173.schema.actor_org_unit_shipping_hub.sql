BEGIN;

INSERT INTO config.upgrade_log (version) VALUES ('1173'); 

CREATE TABLE actor.org_unit_shipping_hub (
    id SERIAL PRIMARY KEY,
    org_unit BIGINT NOT NULL REFERENCES actor.org_unit(id) ON DELETE CASCADE DEFERRABLE,
    hub BIGINT NOT NULL REFERENCES actor.org_unit(id) ON DELETE CASCADE DEFERRABLE
);

CREATE OR REPLACE FUNCTION actor.org_unit_ancestor_shipping_hub(org_id integer)
  RETURNS SETOF actor.org_unit_shipping_hub AS
$func$
DECLARE
    shipping_hub record;
    cur_org INT;
BEGIN
    cur_org := org_id;
    LOOP
        SELECT INTO shipping_hub * FROM actor.org_unit_shipping_hub WHERE org_unit = cur_org;
        IF FOUND THEN
            RETURN NEXT shipping_hub;
            EXIT;
        END IF;
        SELECT INTO cur_org parent_ou FROM actor.org_unit WHERE id = cur_org;
        EXIT WHEN cur_org IS NULL;
    END LOOP;
    RETURN;
END;
$func$ LANGUAGE PLPGSQL;

COMMIT;